#!/usr/bin/env python3
"""Upsert per-sample QC status/metrics onto a Terra workspace entity table.

Reads the `reprep_repool_summary.csv` produced by qc_report.qmd (one row per
sample/Batch/reaction) and upserts one row per sample onto the given Terra
entity table via ops_utils' TerraWorkspace.upload_metadata_with_batch_upsert,
using the credentials of the Cromwell task's attached service account.
"""

import argparse
import csv

from ops_utils.request_util import RunRequest
from ops_utils.terra_util import TerraWorkspace
from ops_utils.token_util import Token

# Worst-status wins when a sample has multiple reactions with different statuses.
STATUS_RANK = {"reprep": 0, "repool": 1, "pass": 2}


def summarize_by_sample(summary_csv_path):
    per_sample = {}
    with open(summary_csv_path, newline="") as f:
        for row in csv.DictReader(f):
            sample_name = row["sample_name"]
            status = row["status"]
            reason = row.get("reason", "")
            entry = per_sample.setdefault(
                sample_name,
                {"status": status, "reasons": set(), "reads_per_reaction_max": 0.0},
            )
            if STATUS_RANK.get(status, 99) < STATUS_RANK.get(entry["status"], 99):
                entry["status"] = status
            if reason and reason != "NA":
                entry["reasons"].add(reason)
            try:
                reads = float(row.get("reads_per_reaction", 0) or 0)
            except ValueError:
                reads = 0.0
            entry["reads_per_reaction_max"] = max(entry["reads_per_reaction_max"], reads)
    return per_sample


def build_row_data(per_sample, id_column):
    return [
        {
            id_column: sample_name,
            "qc_status": metrics["status"],
            "qc_reason": "; ".join(sorted(metrics["reasons"])) or "NA",
            "qc_max_reads_per_reaction": metrics["reads_per_reaction_max"],
        }
        for sample_name, metrics in per_sample.items()
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True, help="Path to reprep_repool_summary.csv")
    parser.add_argument("--workspace-namespace", required=True, help="Terra billing project")
    parser.add_argument("--workspace-name", required=True, help="Terra workspace name")
    parser.add_argument("--entity-type", default="sample", help="Terra entity type to upsert (default: sample)")
    args = parser.parse_args()

    per_sample = summarize_by_sample(args.summary)
    if not per_sample:
        print("No samples found in summary CSV; nothing to upsert.")
        return

    id_column = f"{args.entity_type}_id"
    row_data = build_row_data(per_sample, id_column)

    terra_workspace = TerraWorkspace(
        billing_project=args.workspace_namespace,
        workspace_name=args.workspace_name,
        request_util=RunRequest(token=Token()),
    )
    response = terra_workspace.upload_metadata_with_batch_upsert(
        table_data={
            args.entity_type: {
                "table_id_column": id_column,
                "row_data": row_data,
            }
        }
    )
    response.raise_for_status()
    print(
        f"Upserted QC metrics for {len(row_data)} samples onto '{args.entity_type}' table "
        f"in {args.workspace_namespace}/{args.workspace_name} (HTTP {response.status_code})."
    )


if __name__ == "__main__":
    main()
