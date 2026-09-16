#!/usr/bin/env python3
"""Upsert per-sample QC metrics onto a Terra workspace entity table, and write
a single overall BatchPass value as a plain workflow output.

A workflow run is expected to cover one batch (one sample_set) at a time, so
BatchPass is a single "Pass"/"Fail" value for the whole run, not a per-batch
table. It's written to a plain text file (--batch-pass-output) rather than
upserted onto a Terra sample_set -- there's no reliable way for this script
to know the actual sample_set entity name for this batch -- so the WDL task
reads that file back with read_string() into a String output, the same
pattern move_outputs.wdl uses. That lets Terra map the workflow's batch_pass
output straight onto a data table column as the literal value "Pass"/"Fail".

Also upserts one row per sample onto the `sample` (or --entity-type) table:
SampleType, Batch, Parasitemia, Run (from the manifest), PostprocessedReadCount
(from sample_read_counts.csv), BatchPass, and QCStatus (from
reprep_repool_summary.csv, worst status across a sample's reactions), via
ops_utils' TerraWorkspace.upload_metadata_with_batch_upsert, using the
credentials of the Cromwell task's attached service account.
"""

import argparse

from ops_utils.csv_util import Csv
from ops_utils.request_util import RunRequest
from ops_utils.terra_util import TerraWorkspace
from ops_utils.token_util import Token

# Worst-status wins when a sample has multiple reactions with different statuses.
STATUS_RANK: dict[str, int] = {"reprep": 0, "repool": 1, "pass": 2}

ManifestInfo = dict[str, str]

# Kept in sync with the same check in qc_report.qmd. Unlike R's read.csv, this
# CSV reader has no na.strings conversion, so a literal "NA" stays the string
# "NA" here rather than becoming a missing value -- included in the allowed
# set directly, rather than treated as "unset".
VALID_SAMPLE_TYPES: set[str] = {"positive", "negative", "sample", "NA"}


def read_rows(file_path: str, delimiter: str) -> list[dict[str, str]]:
    return Csv(file_path=file_path, delimiter=delimiter).create_list_of_dicts_from_tsv()


def summarize_qc_status(summary_csv_path: str) -> dict[str, str]:
    """sample_name -> worst status ('reprep' > 'repool' > 'pass') across its reactions."""
    per_sample: dict[str, str] = {}
    for row in read_rows(summary_csv_path, delimiter=","):
        sample_name = row["sample_name"]
        status = row["status"]
        if sample_name not in per_sample or STATUS_RANK.get(status, 99) < STATUS_RANK.get(per_sample[sample_name], 99):
            per_sample[sample_name] = status
    return per_sample


def read_manifest(manifest_path: str) -> dict[str, ManifestInfo]:
    """sample_name -> {SampleType, Batch, Parasitemia, Run}. Run defaults to '' if absent from the manifest.

    generate_qc_report already validates SampleType before this script ever
    runs, so this shouldn't trigger in practice -- kept here for defense in
    depth in case this script is ever run against a manifest directly.
    """
    manifest: dict[str, ManifestInfo] = {}
    invalid: list[tuple[str, str]] = []
    for row in read_rows(manifest_path, delimiter="\t"):
        sample_name = row["sample_name"]
        sample_type = row.get("SampleType", "")
        if sample_type not in VALID_SAMPLE_TYPES:
            invalid.append((sample_name, sample_type))
        manifest[sample_name] = {
            "SampleType": sample_type,
            "Batch": row.get("Batch", ""),
            "Parasitemia": row.get("Parasitemia", ""),
            "Run": row.get("Run", ""),
        }

    if invalid:
        details = ", ".join(f"{sample_name} ('{sample_type}')" for sample_name, sample_type in invalid)
        raise ValueError(
            "SampleType in the manifest file must be one of three options: 'positive', 'negative', or "
            "'sample'. For missing data, insert 'NA'.\n"
            f"Invalid SampleType value(s) found for sample(s): {details}"
        )

    return manifest


def read_sample_read_counts(sample_read_counts_path: str) -> dict[str, str]:
    return {row["sample_name"]: row["PostprocessedReadCount"] for row in read_rows(sample_read_counts_path, delimiter=",")}


def compute_batch_pass(polyclonal_information_path: str, neg_control_information_path: str) -> str:
    """Placeholder rule pending a final definition: this run's batch fails if
    there's any polyclonal positive-control target at all, or any negative
    control over the contamination read threshold at all."""
    for path in (polyclonal_information_path, neg_control_information_path):
        if read_rows(path, delimiter=","):
            return "Fail"
    return "Pass"


def build_sample_row_data(
    qc_status_by_sample: dict[str, str],
    manifest: dict[str, ManifestInfo],
    read_counts: dict[str, str],
    batch_pass: str,
    id_column: str,
) -> list[dict[str, str]]:
    row_data: list[dict[str, str]] = []
    for sample_name, status in qc_status_by_sample.items():
        info = manifest.get(sample_name, {})
        row_data.append(
            {
                id_column: sample_name,
                "SampleType": info.get("SampleType", ""),
                "Batch": info.get("Batch", ""),
                "Parasitemia": info.get("Parasitemia", ""),
                "Run": info.get("Run", ""),
                "PostprocessedReadCount": read_counts.get(sample_name, ""),
                "BatchPass": batch_pass,
                "QCStatus": status,
            }
        )
    return row_data


def write_batch_pass(batch_pass: str, output_path: str) -> None:
    with open(output_path, "w") as f:
        f.write(batch_pass + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True, help="Path to reprep_repool_summary.csv")
    parser.add_argument("--manifest", required=True, help="Path to the sample manifest TSV")
    parser.add_argument("--sample-read-counts", required=True, help="Path to sample_read_counts.csv")
    parser.add_argument("--polyclonal-information", required=True, help="Path to positive_control_polyclonal_info.csv")
    parser.add_argument("--neg-control-information", required=True, help="Path to negative_control_amplified_targets.csv")
    parser.add_argument("--workspace-namespace", required=True, help="Terra billing project")
    parser.add_argument("--workspace-name", required=True, help="Terra workspace name")
    parser.add_argument("--entity-type", default="sample", help="Terra entity type for per-sample rows (default: sample)")
    parser.add_argument("--batch-pass-output", default="batch_pass.txt", help="Path to write this run's overall BatchPass value to")
    args = parser.parse_args()

    qc_status_by_sample = summarize_qc_status(args.summary)
    if not qc_status_by_sample:
        print("No samples found in summary CSV; nothing to upsert.")
        return

    manifest = read_manifest(args.manifest)
    read_counts = read_sample_read_counts(args.sample_read_counts)
    batch_pass = compute_batch_pass(args.polyclonal_information, args.neg_control_information)
    write_batch_pass(batch_pass, args.batch_pass_output)

    id_column = f"{args.entity_type}_id"
    sample_rows = build_sample_row_data(qc_status_by_sample, manifest, read_counts, batch_pass, id_column)

    terra_workspace = TerraWorkspace(
        billing_project=args.workspace_namespace,
        workspace_name=args.workspace_name,
        request_util=RunRequest(token=Token()),
    )
    response = terra_workspace.upload_metadata_with_batch_upsert(
        table_data={
            args.entity_type: {"table_id_column": id_column, "row_data": sample_rows},
        }
    )
    print(
        f"Upserted QC metrics for {len(sample_rows)} samples onto '{args.entity_type}' in "
        f"{args.workspace_namespace}/{args.workspace_name} (HTTP {response.status_code}). "
        f"BatchPass = {batch_pass} (written to {args.batch_pass_output})."
    )


if __name__ == "__main__":
    main()
