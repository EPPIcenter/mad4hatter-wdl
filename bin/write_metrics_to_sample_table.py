#!/usr/bin/env python3
"""Upsert per-sample and per-batch QC metrics onto Terra workspace entity tables.

Combines several qc_report.qmd outputs and the sample manifest into:
- One row per sample on the `sample` (or --entity-type) table:
  SampleType, Batch, Parasitemia, Run (from the manifest), PostprocessedReadCount
  (from sample_read_counts.csv), BatchPass, and QCStatus (from
  reprep_repool_summary.csv, worst status across a sample's reactions).
- One row per Batch on the `sample_set` (or --set-entity-type) table: BatchPass.

Upserts via ops_utils' TerraWorkspace.upload_metadata_with_batch_upsert, using
the credentials of the Cromwell task's attached service account.
"""

import argparse

from ops_utils.csv_util import Csv
from ops_utils.request_util import RunRequest
from ops_utils.terra_util import TerraWorkspace
from ops_utils.token_util import Token

# Worst-status wins when a sample has multiple reactions with different statuses.
STATUS_RANK: dict[str, int] = {"reprep": 0, "repool": 1, "pass": 2}

ManifestInfo = dict[str, str]


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
    """sample_name -> {SampleType, Batch, Parasitemia, Run}. Run defaults to '' if absent from the manifest."""
    manifest: dict[str, ManifestInfo] = {}
    for row in read_rows(manifest_path, delimiter="\t"):
        manifest[row["sample_name"]] = {
            # The notebook only ever expects 'positive', 'negative', or 'sample'
            # here; erroring on anything else is deferred for now.
            "SampleType": row.get("SampleType", ""),
            "Batch": row.get("Batch", ""),
            "Parasitemia": row.get("Parasitemia", ""),
            "Run": row.get("Run", ""),
        }
    return manifest


def read_sample_read_counts(sample_read_counts_path: str) -> dict[str, str]:
    return {row["sample_name"]: row["PostprocessedReadCount"] for row in read_rows(sample_read_counts_path, delimiter=",")}


def compute_batch_pass(
    polyclonal_information_path: str,
    neg_control_information_path: str,
    manifest: dict[str, ManifestInfo],
) -> dict[str, str]:
    """Placeholder rule pending a final definition: a batch fails if any of its
    positive controls has a polyclonal target, or any of its negative controls
    has a target over the contamination read threshold."""
    failing_batches: set[str] = set()

    for path in (polyclonal_information_path, neg_control_information_path):
        for row in read_rows(path, delimiter=","):
            batch = manifest.get(row["sample_name"], {}).get("Batch")
            if batch:
                failing_batches.add(batch)

    all_batches = {info["Batch"] for info in manifest.values() if info["Batch"]}
    return {batch: ("Fail" if batch in failing_batches else "Pass") for batch in all_batches}


def build_sample_row_data(
    qc_status_by_sample: dict[str, str],
    manifest: dict[str, ManifestInfo],
    read_counts: dict[str, str],
    batch_pass: dict[str, str],
    id_column: str,
) -> list[dict[str, str]]:
    row_data: list[dict[str, str]] = []
    for sample_name, status in qc_status_by_sample.items():
        info = manifest.get(sample_name, {})
        batch = info.get("Batch", "")
        row_data.append(
            {
                id_column: sample_name,
                "SampleType": info.get("SampleType", ""),
                "Batch": batch,
                "Parasitemia": info.get("Parasitemia", ""),
                "Run": info.get("Run", ""),
                "PostprocessedReadCount": read_counts.get(sample_name, ""),
                "BatchPass": batch_pass.get(batch, ""),
                "QCStatus": status,
            }
        )
    return row_data


def build_sample_set_row_data(batch_pass: dict[str, str], id_column: str) -> list[dict[str, str]]:
    return [{id_column: batch, "BatchPass": status} for batch, status in batch_pass.items()]


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
    parser.add_argument("--set-entity-type", default="sample_set", help="Terra entity type for per-batch rows (default: sample_set)")
    args = parser.parse_args()

    qc_status_by_sample = summarize_qc_status(args.summary)
    if not qc_status_by_sample:
        print("No samples found in summary CSV; nothing to upsert.")
        return

    manifest = read_manifest(args.manifest)
    read_counts = read_sample_read_counts(args.sample_read_counts)
    batch_pass = compute_batch_pass(args.polyclonal_information, args.neg_control_information, manifest)

    id_column = f"{args.entity_type}_id"
    set_id_column = f"{args.set_entity_type}_id"
    sample_rows = build_sample_row_data(qc_status_by_sample, manifest, read_counts, batch_pass, id_column)
    sample_set_rows = build_sample_set_row_data(batch_pass, set_id_column)

    terra_workspace = TerraWorkspace(
        billing_project=args.workspace_namespace,
        workspace_name=args.workspace_name,
        request_util=RunRequest(token=Token()),
    )
    response = terra_workspace.upload_metadata_with_batch_upsert(
        table_data={
            args.entity_type: {"table_id_column": id_column, "row_data": sample_rows},
            args.set_entity_type: {"table_id_column": set_id_column, "row_data": sample_set_rows},
        }
    )
    print(
        f"Upserted QC metrics for {len(sample_rows)} samples onto '{args.entity_type}' and "
        f"{len(sample_set_rows)} batches onto '{args.set_entity_type}' in "
        f"{args.workspace_namespace}/{args.workspace_name} (HTTP {response.status_code})."
    )


if __name__ == "__main__":
    main()
