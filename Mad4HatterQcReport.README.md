# Mad4HatterQcReport

This workflow generates the QC report for a completed **Mad4hatter** run — which may span multiple
batches — and writes per-sample QC metrics back onto the Terra `sample` (or `--entity-type`) data
table. It takes the postprocessed outputs of `Mad4Hatter.wdl` (or `Mad4HatterQcOnly.wdl`) as input
rather than FASTQs.

### Inputs:

| Input Name                           | Description                                                                                                                                     | Type    | Required | Default                                                                                   |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|---------|----------|-------------------------------------------------------------------------------------------|
| **sample_coverage**                  | Postprocessed sample coverage file from the Mad4hatter run.                                                                                     | File    | Yes      | -                                                                                         |
| **amplicon_coverage**                | Postprocessed amplicon coverage file from the Mad4hatter run.                                                                                   | File    | Yes      | -                                                                                         |
| **allele_data**                      | The allele table from the Mad4hatter run.                                                                                                       | File    | Yes      | -                                                                                         |
| **allele_table_collapsed**           | The collapsed allele table from the Mad4hatter run.                                                                                             | File    | Yes      | -                                                                                         |
| **amplicon_info**                    | The panel's amplicon info file.                                                                                                                 | File    | Yes      | -                                                                                         |
| **resmarker_table**                  | The resistance marker table from the Mad4hatter run.                                                                                            | File    | Yes      | -                                                                                         |
| **resmarker_microhaplotype_table**   | The resistance marker microhaplotype table from the Mad4hatter run.                                                                             | File    | Yes      | -                                                                                         |
| **manifest**                         | Sample manifest TSV (`sample_name`, `SampleType`, `Batch`, `Column`, `Row`, `Parasitemia`).                                                     | File    | Yes      | -                                                                                         |
| **standardise_sample_name**          | Whether to strip the sequencer suffix (e.g. `_S1`) from sample names before matching to the manifest.                                           | Boolean | No       | true                                                                                      |
| **read_threshold**                   | Minimum reads for a target to be considered successfully amplified.                                                                             | Int     | No       | 100                                                                                       |
| **read_filter**                      | Minimum reads for an ASV to be counted when assessing positive-control polyclonality.                                                           | Int     | No       | 0                                                                                         |
| **af_filter**                        | Minimum within-sample allele frequency for an ASV to be counted toward polyclonality.                                                           | Float   | No       | 0.01                                                                                      |
| **negative_control_read_threshold**  | Minimum reads for a target in a negative control to be flagged as contamination.                                                                | Int     | No       | 50                                                                                        |
| **reprep_threshold**                 | Proportion of good loci below which a sample is flagged for reprep.                                                                             | Float   | No       | 0.5                                                                                       |
| **repool_threshold**                 | Proportion of good loci below which a sample is flagged for repool (but above `reprep_threshold`).                                              | Float   | No       | 0.75                                                                                      |
| **allele_col**                       | Column used to distinguish alleles when summarizing positive-control polyclonality.                                                             | String  | No       | pseudocigar_masked                                                                        |
| **long_target_threshold**            | Amplicon length (bp, including primers) above which a target is excluded from the QC loci.                                                      | Int     | No       | 275                                                                                       |
| **filter_wsaf_final_allele_table**   | Whether the filtered allele/resmarker outputs also require within-sample allele frequency > `af_filter` (in addition to reads > `read_filter`). | Boolean | No       | true                                                                                      |
| **reaction_as_pool**                 | Whether to treat each pool as its own mPCR reaction, instead of deriving the reaction from the pool name.                                       | Boolean | No       | false                                                                                     |
| **workspace_name**                   | Terra workspace name to write QC metrics back to. Detected from the running Terra submission if omitted.                                         | String  | No       | (detected)                                                                                |
| **workspace_billing_project**        | Terra billing project (namespace) for `workspace_name`. Detected from the running Terra submission if omitted.                                   | String  | No       | (detected)                                                                                |
| **sample_table**                     | Terra entity/table name to upsert per-sample QC metrics onto.                                                                                   | String  | Yes      | -                                                                                         |
| **docker_image**                     | Docker image used for both the report-generation and sample-table-upload tasks.                                                                 | String  | No       | us-central1-docker.pkg.dev/operations-portal-427515/qc-report/mad4hatter-qc-report:latest |

### Outputs:

| Output Name                                 | Description                                                                 | Type |
|---------------------------------------------|-----------------------------------------------------------------------------|------|
| **qc_report_html**                          | The rendered QC report.                                                     | File |
| **reprep_repool_summary**                   | Per-sample, per-reaction QC outcome (`pass`/`repool`/`reprep`).             | File |
| **samples_to_repool**                       | Samples flagged for repool.                                                 | File |
| **samples_to_reprep**                       | Samples flagged for reprep.                                                 | File |
| **polyclonal_information**                  | Positive controls with multiallelic targets.                                | File |
| **neg_control_information**                 | Negative controls with targets above the contamination read threshold.      | File |
| **missing_samples_report**                  | Manifest samples missing from the allele data.                              | File |
| **missing_targets_report**                  | Missing sample/target combinations.                                         | File |
| **filtered_allele_data**                    | Allele table filtered by `read_filter` (and `af_filter`, if enabled).       | File |
| **filtered_collapsed_allele_data**          | Collapsed allele table filtered the same way.                               | File |
| **filtered_resmarker_table**                | Resistance marker table filtered the same way.                              | File |
| **filtered_resmarker_microhaplotype_table** | Resistance marker microhaplotype table filtered the same way.               | File |
| **sample_read_counts**                      | Postprocessed read count per sample.                                        | File |

### Writes to the Terra sample table

In addition to the file outputs above, this workflow upserts one row per sample onto the Terra
`sample_table` (default `sample`), using the credentials of the Cromwell task's attached service
account:

| Column                       | Description                                                                                       |
|------------------------------|---------------------------------------------------------------------------------------------------|
| **library_sample_name**      | QC sample name without the sequencer suffix.                                                      |
| **sample_type**              | `positive`, `negative`, `sample`, or `NA`, from the manifest.                                     |
| **batch**                    | Batch, from the manifest.                                                                         |
| **parasites_per_ul**         | Parasitemia, from the manifest.                                                                   |
| **sequencing_run**           | Sequencing run, from the manifest.                                                                |
| **postprocessed_read_count** | Postprocessed read count for the sample.                                                          |
| **batch_pass**               | Whether the sample's batch passed QC — see below.                                                 |
| **Library_sample_qc_status** | Worst QC status (`reprep` > `repool` > `pass`) across the sample's reactions.                     |
| **mean_prop_good_loci**      | Mean proportion of good loci across the sample's reactions.                                       |

A single run can contain multiple batches, so `batch_pass` is computed once per batch (not once
per run) and the same value is written onto every sample belonging to that batch:

* **`PASS`** — every positive control in the batch has `status == "pass"` in every reaction *and*
  is absent from `polyclonal_information` (monoclonal), and every negative control in the batch is
  absent from `neg_control_information` (uncontaminated).
* **`NoControls`** — the batch has no positive controls, no negative controls, or neither.
* **`CheckManually`** — the batch has both control types, but at least one of the `PASS` conditions
  above isn't met.
