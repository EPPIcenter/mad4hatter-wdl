# Malaria Plasmodium Illumina Mad4Hatter Amplicon Workspace for Processing of Sequencing Data
<img src="https://storage.googleapis.com/broad-malaria-public/mad4hatter_workspace_data/00_mad4hatter_logo.png" alt="Mad4hatter logo" height="160">

Welcome to the Mad4hatter workspace!

This workspace hosts workflows for processing *Plasmodium* amplicon sequencing data. Amplicon sequencing is a targeted DNA sequencing technique that selectively amplifies and sequences specific regions of interest within a genome. [MAD4HatTeR and PfPHAST](https://eppicenter.ucsf.edu/resources) are amplicon sequencing panels that target highly diverse loci, focusing on multiallelic microhaplotypes, key markers for drug resistance, and csp and potential vaccine targets. The panels can also detect non-falciparum Plasmodium species.

`01_Mad4Hatter` (for the MAD4HatTeR panel) and `01_PfPhast` (for the PfPHAST panel) process raw FASTQ files from a single sequencing run and produces an allele table containing microhaplotype sequences and pseudo-CIGARS, core QC metrics, and drug resistance information. These outputs require additional filtering and quality control before being combined with data from other sequencing runs or used for downstream analysis. Run `02_AmpliconPanelQcReport` on the panel workflow's outputs and critically assess the QC results before proceeding with downstream analysis.

The workflows in this workspace are a translated implementation of the original MAD4HatTeR Nextflow pipeline developed by the EPPIcenter (UCSF). The translation to Terra was carried out in collaboration between the EPPIcenter and the Broad Institute Malaria Genomics Group and DSP Pipelines Team.

Comprehensive documentation can be found [here](https://eppicenter.github.io/wonderland-docs/).

## Overview of workflows:

**The numeric prefix is the run order** — run `01`, then `02`, then `03`. Workflows without a numeric prefix are not part of the supported sequence.

There are **two alternative `01` workflows, one per panel**. They are the same underlying pipeline with the pools preconfigured, so pick the one matching your panel and run only that one. Both feed the same `02` and `03`.

* **`01_Mad4Hatter`** — The full end-to-end pipeline for the **MAD4HatTeR** panel, from raw FASTQs through microhaplotype calling and drug-resistance profiling. Pools are preset to `["D1.1", "R1.2", "R2.1"]`. A comprehensive description of the outputs can be found [here](https://eppicenter.github.io/wonderland-docs/pipeline-outputs/).

* **`01_PfPhast`** — The same pipeline configured for the **PfPHAST** panel, with pools preset to `["M1.1", "M2.1"]`. Identical inputs and outputs to `01_Mad4Hatter`; only the preset pools and the data table it runs on differ.

* **`02_AmpliconPanelQcReport`** — Generates the QC report for a single completed `01_Mad4Hatter` run (one sample set at a time), produces filtered copies of the allele and resistance-marker tables, and **writes per-sample QC metrics back onto the per-sample data table**. It takes the outputs of `01_Mad4Hatter` as input rather than FASTQs.

* **`03_ExtractDrugResistanceMarkers`** — Takes a *Plasmodium* amplicon allele table (or PMO file) and translates the amplicon sequences at loci of interest into amino acid calls, giving per-sample drug-resistance marker calls. It then estimates resistance allele frequencies from those calls, per population when a population assignment is given, producing single-locus and multi-locus frequencies for defined loci groups. Summary tables are linked through the sample set table, and **per-sample amino acid calls are written back onto the per-sample data table**.

> **Two of these workflows write directly into your data tables** in addition to returning files. See [Columns written directly into your data tables](#columns-written-directly-into-your-data-tables) for the full list.

## Creating and Setting Up Your Terra Workspace for Mad4Hatter

If you don't have a Terra account, you can create an account by following the instructions [here](https://support.terra.bio/hc/en-us/articles/360028235911-How-to-register-on-Terra-Google-SSO). Otherwise sign in to your Terra account to proceed.

### Clone the Workspace
To begin, clone this workspace by following [these directions](https://support.terra.bio/hc/en-us/articles/360026130851-How-to-clone-your-own-workspace). This workspace already has the Mad4Hatter workflows imported and contains an example dataset including 5 samples [Brokhattingen, N., et. al (2024)](https://www.nature.com/articles/s41467-024-46535-x).

### Importing New Data and Setting up Metadata
To run `01_Mad4Hatter` on your own FASTQ files, follow [these directions](https://support.terra.bio/hc/en-us/articles/4419428208411-Upload-data-and-populate-the-table-with-linked-file-paths) until "Step 3. Upload Files" and continue below. `02_AmpliconPanelQcReport` and `03_ExtractDrugResistanceMarkers` use the outputs of a completed `01_Mad4Hatter` run, so they do not need a separate raw data upload; `02_AmpliconPanelQcReport` additionally needs a manifest file (see below).
Each collection should correspond to a single sequencing run, since the workflows and QC are designed to be applied at the run level.

When selecting files for upload, please note the following:
* Only FASTQ files should be included in a set. Other file types (e.g., txt files) will cause the workflow to fail, so be sure to exclude any non-FASTQ files when selecting from a folder.
* Do not include undetermined FASTQ files. These should be excluded from the set.

After uploading your data files, click **Next**. Choose the **autogenerate** option and select **"AUTOGENERATE TABLE FOR SINGLE OR PAIRED END SEQUENCING."** Review the table preview, then click **Create Table**. The generated table will use the same name as the collection created in the first step.

<img src="https://raw.githubusercontent.com/EPPIcenter/wonderland-docs/main/docs/assets/images/terra_workspace_screenshots/autogenerate_table.png"
     alt="autogenerate_table"
     >

## Running Workflows

All of these workflows run on a **sample set** table (`rootEntityType` is `<your_table>_set`), one set per sequencing run.

### Running 01_Mad4Hatter / 01_PfPhast
Run **one** of these, whichever matches your panel. They differ only in the preset `pools` and the data table they are configured against:

| Workflow | Panel | Preset `pools` | Data table |
|---|---|---|---|
| `01_Mad4Hatter` | MAD4HatTeR | `["D1.1", "R1.2", "R2.1"]` | `mad4hatter_sample_set` (5 samples) |
| `01_PfPhast` | PfPHAST | `["M1.1", "M2.1"]` | `pfphast_sample_set` (3 sets over 429 samples) |

`02` and `03` read their inputs from columns that `01` writes onto the set row, so **`01` must run first** — on a freshly cloned workspace the set row holds only its sample membership and `02`/`03` have nothing to resolve yet.

`02_AmpliconPanelQcReport` and `03_ExtractDrugResistanceMarkers` are configured against `mad4hatter_sample_set`, but nothing in their inputs names a specific table — every file input is a `this.{column}` reference that resolves on whichever set you launch against. To run them on a PfPHAST set, just select `pfphast_sample_set` when you launch; no input edits are needed.

1. Navigate to the **"Workflows"** tab in your Terra workspace.
2. Select **`01_Mad4Hatter`** or **`01_PfPhast`**.

<img src="https://raw.githubusercontent.com/EPPIcenter/wonderland-docs/main/docs/assets/images/terra_workspace_screenshots/mh_2.png"
     alt="mh_2"
     >

3. Select the data table that is named like `YOUR_TABLE_set`. This is the table containing your forward and reverse reads, with `_set` appended to the original table name. For example, if your table is named `mad4hatter_sample`, select `mad4hatter_sample_set`. Running it as a set lets the workflow treat all forward/reverse read pairs as one coherent dataset, rather than as a bunch of unrelated samples.
4. Click **"Select Data"** and choose the set row to run on.
5. Check the inputs. `forward_fastqs` and `reverse_fastqs` reference the read columns of the member table through the set's membership attribute — in this workspace both set tables use `samples`, so they are `this.samples.read1` and `this.samples.read2`. If you build your own set table the membership attribute is named after it, so confirm the expression matches. `pools` is already preset for the panel, so you normally leave it alone (see [Pool Options](#pool-options) if you need to change it). `output_directory` is a plain subdirectory name such as `"outputs"` — see the note on that input below.
6. Click **"Launch"**, then monitor progress in the **"Submission History"** tab.
7. When it finishes, the output paths are written onto the sample set row in the **"Data"** tab.

### Running 02_AmpliconPanelQcReport

#### Step 1: Upload Your Manifest File
`02_AmpliconPanelQcReport` needs a manifest TSV describing the samples in the run, with the columns `sample_name`, `SampleType`, `Batch`, `Column`, `Row`, `Parasitemia` and optionally `Run` (which populates `sequencing_run`; omit it and that column is left empty).

Every set row in this workspace carries its manifest in a **`qc_manifest`** column, and the `manifest` input is set to `this.qc_manifest`, so there is nothing to configure. For your own data, upload the manifest to the workspace bucket and put its path in a `qc_manifest` column on the set row. Note each set uses its own manifest, so a run only writes QC columns for the samples that set's manifest covers. Required columns are `sample_name`, `SampleType`, `Batch`, `Column`, `Row`, `Parasitemia`; `Run` is used for `sequencing_run` when present.

#### Step 2: Setting up and running the workflow
1. Navigate to the **"Workflows"** tab and select **`02_AmpliconPanelQcReport`**.
2. Select the same `YOUR_TABLE_set` table and the set row you ran `01_Mad4Hatter` or `01_PfPhast` on.
3. Configure the inputs. The seven file inputs (`sample_coverage`, `amplicon_coverage`, `allele_data`, `allele_table_collapsed`, `amplicon_info`, `resmarker_table`, `resmarker_microhaplotype_table`) are all available on the sample set row and should be set to `this.{column_name}`, e.g. `this.allele_data`. Add the `manifest` file.
4. **Leave the workspace, billing project and data table inputs empty** — they are optional and worked out from the submission. See [Workspace and table detection](#workspace-and-table-detection).
5. Click **"Launch"**.
6. When it finishes, review `qc_report_html` and the per-sample QC columns written onto your data table before continuing.

### Running 03_ExtractDrugResistanceMarkers
1. Navigate to the **"Workflows"** tab and select **`03_ExtractDrugResistanceMarkers`**.
2. Select the same `YOUR_TABLE_set` table and the set row. That set must already have `01_Mad4Hatter` (or `01_PfPhast`) **and** `02_AmpliconPanelQcReport` outputs populated.
3. Configure the inputs. `amplicon_info`, `filtered_allele_data` and `reference` are all available on the sample set row and should be set to `this.{column_name}`. Note `filtered_allele_data` comes from `02_AmpliconPanelQcReport`, not from the `01` panel workflow.
4. `loci_groups` and `loci_of_interest_bed` are already pointed at panel defaults in the public `broad-malaria-public` bucket, so you can leave them alone:

   - `loci_groups` → `gs://broad-malaria-public/mad4hatter_workspace_data/default_loci_groups.tsv` — a TSV/CSV defining the multi-locus groups that multi-locus estimates are computed for.
   - `loci_of_interest_bed` → `gs://broad-malaria-public/mad4hatter_workspace_data/default_principal_resistance_marker_info_table.bed` — a BED of the loci that single-locus estimates are computed at.

   To use your own instead, upload them to the workspace bucket and select them with the "Browse bucket files" folder button next to the input. Reference examples live in the [plasmodiumdrugres-wdl repo](https://github.com/PlasmoGenEpi/plasmodiumdrugres-wdl/tree/main/tests/input).
5. **Leave the workspace, billing project, data table and bucket inputs empty** — they are optional and worked out from the submission. See [Workspace and table detection](#workspace-and-table-detection).
6. Click **"Launch"**.
7. View outputs in the **"Data"** tab: summary files on the sample set row, and per-sample `resmarker_*` columns on the per-sample table.

## Workspace and table detection

`02_AmpliconPanelQcReport` and `03_ExtractDrugResistanceMarkers` write back into your data tables, so they need to know which workspace and which table to write to. They work this out from the submission itself, so **the workspace, billing project, data table and bucket inputs are all optional and can be left empty**. You may set them to this workspace's values if you prefer to be explicit, but it is not required.

Row ids are matched before anything is written: a specimen named `SRR26819135` is matched to the existing row `SRR26819135_S1_L001`, so the real row is updated rather than a new, half-empty row being created beside it. Specimens with no match, or more than one, are skipped and reported in the task log.

## Pool Options

The workflows support MaD4HatTeR and PfPHAST as well as several other configured panels.
While the workflows can be run on any panel, they were optimised using MAD4HatTeR data; panels with substantially different properties, such as very short amplicon targets, may require additional tuning to achieve optimal performance.

If your panel isn't listed in the table below, you can provide your own panel configuration files. Use the `amplicon_info_files` parameter along with either `genome` (whole genome reference) or `refseq_fasta` (targeted reference). Follow instructions under [Option 1: Using Command-Line Parameters](https://eppicenter.github.io/wonderland-docs/custom-pools/) to create the necessary files.

**`01_Mad4Hatter` and `01_PfPhast` already have their pools preconfigured** (`["D1.1", "R1.2", "R2.1"]` and `["M1.1", "M2.1"]` respectively), so you only need this section if you are running a different panel or changing the pool selection.

Pools should be provided as a comma-separated list, with each pool enclosed in quotation marks (e.g., `["D1.1","R1.2","R2.1"]` or `["ama1"]`). Valid pool options are listed in the `'Pool Name'` column below. Where available, the `'Shorthand Name'` may also be used.

| Pool Name | Description | Shorthand Name | Legacy pool name |
|:---------:|:------------|:---------------|:-----------------|
| **MAD4HatTeR Pools** |
| **D1.1** | A primer pool targeting 165 high diversity targets and 5 loci targetting the ldh gene in P. falciparum and in 4 non-falciparum Plasmodium species (P. vivax, P. malariae, P. ovale, and P. knowlesi) |  D1 | 1A |
| **R1.1** | 82 targets informing drug and diagnostic resistance, Plasmodium species identification, immune-related targets | - | 1B |
| **R1.2** | R1.2 is a reduced version of primer pool R1.1, containing 47 targets, designed to reduce primer dimers and increase sensitivity | R1 | 5 |
| **R2.1** | 31 targets to provide information on drug and diagnostic resistance, Plasmodium species identification, immune-related targets. This complements R1, covering missing codons | R2 | 2 |
| **PfPHAST Pools** |
| **M1.1** | 41 targets for drug and diagnostic resistance, Plasmodium spp. identification, csp, and 10 diversity targets. "Minimal" set for prioritary markers and TES classification | M1 | - |
| **M2.1** | 15 targets for drug and diagnostic resistance, Plasmodium spp. identification, csp, and 10 diversity targets. "Minimal" set for prioritary markers and TES classification. Complements M1.1 for missing codons | M2 | - |
| **M1.addon** | 4 targets for P. vivax, P. malariae, P. ovale and P. knowlesii mitochondrial cytb targets for increased sensitivity in non-Pf detection (recommended to add to M1.1) | - | - |
| **Other Pools/ Panels** |
| **4cast** | 4CAST is a small multiplex of four highly polymorphic antigenic loci: CSP, AMA1, SERA2 and TRAP. For more information, see LaVerriere et al. (2021). | - | - |
| **ama1** | A single-target panel for analyzing diversity in the apical membrane antigen 1 (AMA1) gene, which is important for invasion of red blood cells by Plasmodium parasites. This panel is useful for studying AMA1 genetic diversity and population structure. For more information, see Miller et al. (2017). | - | - |
| **AMPLseq** | 129-locus panel composed of drug resistance markers, highly diverse loci for inferring relatedness, and a locus to detect Plasmodium vivax co-infection. For more information, see LaVerriere et al. (2021). | - | - |
| **spotmalaria_grc1** | Spot malaria pool for GRC1 targets. For more information, see Jacob CG et al. (2021)| - | - |
| **spotmalaria_grc2** | Spot malaria pool for GRC2 targets. For more information, see Jacob CG et al. (2021)| - | - |
| **spotmalaria_spec** | Spot malaria pool for species identification targets. For more information, see Jacob CG et al. (2021)| - | - |
| **v1** | Version 1 of the MADHatTeR panel | - | - |
| **v2** | Version 2 of the MADHatTeR panel | - | - |

## Compute Cost

Use of the Terra platform itself is free, users pay only for the cloud compute resources they use to store and process their data. The Gates Foundation is currently covering these costs for the malaria community! If you would like to use Terra please contact us so we can help you get set up with an account. More information about the costs of storing and analyzing data in the cloud can be found [here](https://docs.google.com/document/d/e/2PACX-1vTPQC-bYMRxXQ4Gz9ESH_Eo-E6UXD2qOL7_3iMxJaQF3pOyW3tUyu7G9Nvk-JTf8xDkOyhftvd9L-sa/pub).

The table below summarises current cost estimates from running the full `01` panel workflow on a set of real datasets, varying both the number of targets and the number of samples. The cost shown reflects the total compute cost for each complete workflow run across the full batch of samples, and then cost per sample (Total Cost/ Samples).

| Panel Type               | Samples | Time                | Total Cost | Cost / Sample |
|--------------------------|---------|---------------------|------------|---------------|
| PfPHAST (57 targets)     | 217     | 2 hours 43 minutes  | $1.17      | $0.005        |
| PfPHAST (57 targets)     | 1,152   | 9 hours 41 minutes  | $7.42      | $0.006        |
| MAD4HatTeR (243 targets) | 96      | 3 hours 28 minutes  | $1.01      | $0.01         |
| MAD4HatTeR (243 targets) | 149     | 4 hours 53 minutes  | $1.55      | $0.01         |
| MAD4HatTeR (243 targets) | 506     | 13 hours 2 minutes  | $7.02      | $0.01         |
| MAD4HatTeR (243 targets) | 862     | 25 hours 13 minutes | $24.02     | $0.03         |

*Cost estimates made Dec 2025.*

## Updating Workflow Version

The workflows in this workspace are configured against the following versions:

| Workflow | Source | Version |
|---|---|---|
| `01_Mad4Hatter` | `github.com/EPPIcenter/mad4hatter-wdl/Mad4Hatter` | `v1.0.4` |
| `01_PfPhast` | `github.com/EPPIcenter/mad4hatter-wdl/Mad4Hatter` | `v1.0.4` |
| `02_AmpliconPanelQcReport` | `github.com/EPPIcenter/mad4hatter-wdl/Mad4HatterQcReport` | `JTS_hotfixes` |
| `03_ExtractDrugResistanceMarkers` | `github.com/jonn-smith/plasmodiumdrugres-wdl/plasmodiumdrugres` | `jts_hotfixes` |

If you need to update to a new version follow [these instructions](https://support.terra.bio/hc/en-us/articles/360026443092-Updating-workflows-to-the-latest-version).

## Input and Output Information for Workflows

### 01_Mad4Hatter and 01_PfPhast

Both run the same pipeline (the `MAD4HatTeR` workflow in `Mad4Hatter.wdl`), which processes amplicon sequencing data to produce allele tables, microhaplotypes, resistance markers, and other useful outputs. **The inputs and outputs below apply to both**; they differ only in the preset `pools` value and the data table each is configured against.

##### Inputs:

| Input Name               | Description                                                                                                                      | Type          | Required | Default                       |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------|---------------|----------|-------------------------------|
| **pools**                | List of pool names. **Already preset per panel** — `["D1.1", "R1.2", "R2.1"]` for `01_Mad4Hatter`, `["M1.1", "M2.1"]` for `01_PfPhast`. If `amplicon_info_files` or `targeted_reference_files` are not provided then the pool defaults are used for both. | Array[String] | Yes | preset per panel |
| **forward_fastqs**       | Reference to the column of forward FASTQs on the member table, e.g. `this.mad4hatter_samples.read1`.                             | Array[File]   | Yes     | - |
| **reverse_fastqs**       | Reference to the column of reverse FASTQs on the member table, e.g. `this.mad4hatter_samples.read2`.                             | Array[File]   | Yes     | - |
| **output_directory**     | Name of the subdirectory to write final outputs into, **not** a `gs://` path. Letters, numbers, `-` and `_` only; validated at workflow start. Files land in `gs://<workspace-bucket>/<output_directory>/<timestamp>/`. | String | Yes | - |
| **amplicon_info_files**  | Amplicon info files. Used to make the concatenated amplicon info file.                                                           | Array[File]?  | No      | - |
| **targeted_reference_files** | Targeted reference files. Used to create `reference.fasta`.                                                                  | Array[File]?  | No      | - |
| **refseq_fasta**         | Path to targeted reference sequences. Auto-generated if not provided; if not provided, `genome` must be.                         | File?         | No      | - |
| **genome**               | Path to genome file. One of `genome` or `refseq_fasta` may be provided, not both.                                                | File?         | No      | - |
| **masked_fasta**         | Masked FASTA file.                                                                                                               | File?         | No      | - |
| **principal_resmarkers** | Principal resistance markers file.                                                                                               | File?         | No      | - |
| **resmarkers_info_tsv**  | Resistance markers info TSV file.                                                                                                | File?         | No      | - |
| **pool_options_json**    | Custom pool options JSON. Must already be present on the Docker image.                                                           | File          | No      | /opt/mad4hatter/conf/terra_panel.json |
| **omega_a**              | Level of statistical evidence required for DADA2 to infer a new ASV.                                                             | Float         | No      | 1e-120 |
| **dada2_pool**           | Pooling method for DADA2 to process ASVs: `pseudo`, `true` or `false`.                                                           | String        | No      | pseudo |
| **band_size**            | Limit on net cumulative number of insertions in DADA2.                                                                           | Int           | No      | 16 |
| **max_ee**               | Limit on number of expected errors within a read in DADA2.                                                                       | Int           | No      | 3 |
| **max_mismatch**         | Mismatches allowed when merging reads in DADA2.                                                                                  | Int           | No      | 0 |
| **cutadapt_minlen**      | Minimum length for cutadapt.                                                                                                     | Int           | No      | 100 |
| **allowed_errors**       | Allowed errors for cutadapt.                                                                                                     | Int           | No      | 0 |
| **quality_score**        | Quality score threshold used during trimming.                                                                                    | Int           | No      | 20 |
| **gtrim**                | Whether to apply global trimming.                                                                                                | Boolean       | No      | false |
| **just_concatenate**     | If true, concatenate reads instead of merging them.                                                                              | Boolean       | No      | **true** |
| **mask_tandem_repeats**  | Mask tandem repeats.                                                                                                             | Boolean       | No      | true |
| **mask_homopolymers**    | Mask homopolymers.                                                                                                               | Boolean       | No      | true |
| **dada2_additional_memory** | Additional memory (GB) added to the memory used in the DADA2 runtime configuration.                                           | Int           | No      | 0 |
| **dada2_runtime_size**   | DADA2 runtime size: `small`, `medium` or `large`. Based on input dataset size; calculated if not provided.                        | String?       | No      | - |
| **docker_image**         | The Docker image to use.                                                                                                         | String        | No      | eppicenter/mad4hatter:v1.0.0 |

##### Outputs:

For more information on individual files, see [here](https://eppicenter.github.io/wonderland-docs/pipeline-outputs/).

These outputs are **GCS paths as `String`s**, not `File`s — the workflow stages the files into `gs://<workspace-bucket>/<output_directory>/<timestamp>/` and returns their locations.

| Output Name                      | Description                                                                                  | Type   |
|----------------------------------|----------------------------------------------------------------------------------------------|--------|
| **allele_data** | Main allele table (unmasked and masked sequences) | String |
| **allele_table_collapsed** | Collapsed allele table (masked sequences only) | String |
| **sample_coverage** | Sample-level coverage statistics | String |
| **amplicon_coverage** | Amplicon-level coverage statistics | String |
| **dada2_clusters** | Raw DADA2 output (ASV sequences and counts) before filtering | String |
| **resmarker_table** | Resistance marker table showing codon-level information summing reads from any overlapping targets | String |
| **resmarker_table_by_locus** | Resistance marker table showing codon-level information per target for resistance markers | String |
| **resmarker_microhaplotype_table** | Table showing combinations of codons from the same microhaplotype for resistance markers of interest | String |
| **all_mutations_table** | Mutation table showing all single-nucleotide variants (SNVs) in targets that covered at least one marker of interest | String |
| **amplicon_info** | Target definitions (targets, primers, coordinates) | String |
| **reference** | FASTA containing reference sequence for each target | String |
| **resmarker_info** | Table of resistance markers covered by the panel and reported on by the workflow | String |

##### Writes directly into data tables:

**None.** The `01` panel workflows return file paths only; everything that lands in your tables comes from the output mappings above.

### 02_AmpliconPanelQcReport

Generates the QC report for one completed `01_Mad4Hatter` run, produces filtered copies of the allele and resistance-marker tables, and writes per-sample QC metrics onto the per-sample data table.

##### Inputs:

| Input Name                           | Description                                                                                                                                     | Type    | Required | Default                                                                                   |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|---------|----------|-------------------------------------------------------------------------------------------|
| **sample_coverage**                  | Postprocessed sample coverage file from the `01_Mad4Hatter` run.                                                                                | File    | Yes      | - |
| **amplicon_coverage**                | Postprocessed amplicon coverage file from the `01_Mad4Hatter` run.                                                                              | File    | Yes      | - |
| **allele_data**                      | The allele table from the `01_Mad4Hatter` run.                                                                                                  | File    | Yes      | - |
| **allele_table_collapsed**           | The collapsed allele table from the `01_Mad4Hatter` run.                                                                                        | File    | Yes      | - |
| **amplicon_info**                    | The panel's amplicon info file.                                                                                                                 | File    | Yes      | - |
| **resmarker_table**                  | The resistance marker table from the `01_Mad4Hatter` run.                                                                                       | File    | Yes      | - |
| **resmarker_microhaplotype_table**   | The resistance marker microhaplotype table from the `01_Mad4Hatter` run.                                                                        | File    | Yes      | - |
| **manifest**                         | Sample manifest TSV (`sample_name`, `SampleType`, `Batch`, `Column`, `Row`, `Parasitemia`; `Run` used for `sequencing_run` when present).        | File    | Yes      | - |
| **workspace_name**                   | Terra workspace whose data table is updated. Optional — may be left empty.                                                                       | String? | No       | (detected) |
| **workspace_billing_project**        | Terra billing project (namespace) for `workspace_name`. Optional — may be left empty.                                                            | String? | No       | (detected) |
| **sample_table**                     | Terra data table to upsert per-sample QC metrics onto. Optional — may be left empty.                                                             | String? | No       | (detected) |
| **standardise_sample_name**          | Whether to strip the sequencer suffix (e.g. `_S1`) from sample names before matching to the manifest.                                           | Boolean | No       | true |
| **read_threshold**                   | Minimum reads for a target to be considered successfully amplified.                                                                             | Int     | No       | 100 |
| **read_filter**                      | Minimum reads for an ASV to be counted when assessing positive-control polyclonality.                                                           | Int     | No       | 0 |
| **af_filter**                        | Minimum within-sample allele frequency for an ASV to be counted toward polyclonality.                                                           | Float   | No       | 0.01 |
| **negative_control_read_threshold**  | Minimum reads for a target in a negative control to be flagged as contamination.                                                                | Int     | No       | 50 |
| **reprep_threshold**                 | Proportion of good loci below which a sample is flagged for reprep.                                                                             | Float   | No       | 0.5 |
| **repool_threshold**                 | Proportion of good loci below which a sample is flagged for repool (but above `reprep_threshold`).                                              | Float   | No       | 0.75 |
| **allele_col**                       | Column used to distinguish alleles when summarizing positive-control polyclonality.                                                             | String  | No       | pseudocigar_masked |
| **long_target_threshold**            | Amplicon length (bp, including primers) above which a target is excluded from the QC loci.                                                      | Int     | No       | 275 |
| **filter_wsaf_final_allele_table**   | Whether the filtered outputs also require within-sample allele frequency > `af_filter` in addition to reads > `read_filter`.                     | Boolean | No       | true |
| **reaction_as_pool**                 | Whether to treat each pool as its own mPCR reaction, instead of deriving the reaction from the pool name.                                        | Boolean | No       | false |
| **docker_image**                     | Docker image used for both the report-generation and data-table-upload tasks.                                                                    | String  | No       | us-central1-docker.pkg.dev/operations-portal-427515/qc-report/mad4hatter-qc-report:v1.0.3 |

Advanced, task-level overrides also exist (`get_terra_env_info.namespace`, `get_terra_env_info.workspace`) for forcing the detected workspace. Leave them empty under normal use.

##### Outputs:

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
| **filtered_allele_data**                    | Allele table filtered by `read_filter` (and `af_filter`, if enabled). **This is the input `03_ExtractDrugResistanceMarkers` consumes.** | File |
| **filtered_collapsed_allele_data**          | Collapsed allele table filtered the same way.                               | File |
| **filtered_resmarker_table**                | Resistance marker table filtered the same way.                              | File |
| **filtered_resmarker_microhaplotype_table** | Resistance marker microhaplotype table filtered the same way.               | File |
| **sample_read_counts**                      | Postprocessed read count per sample.                                        | File |

##### Writes directly into data tables:

In addition to the file outputs above, this workflow upserts one row per sample onto `sample_table`, using the credentials of the Cromwell task's attached service account. Row ids are matched to the existing table before writing (see [Workspace and table detection](#workspace-and-table-detection)).

| Column                       | Description                                                                                       |
|------------------------------|---------------------------------------------------------------------------------------------------|
| **Library_sample_name**      | QC sample name without the sequencer suffix.                                                      |
| **Library_sample_qc_status** | Worst QC status (`reprep` > `repool` > `pass`) across the sample's reactions.                      |
| **mean_prop_good_loci**      | Mean proportion of good loci across the sample's reactions.                                       |
| **postprocessed_read_count** | Postprocessed read count for the sample.                                                          |
| **batch_pass**               | QC outcome for the sample's batch: `PASS`, `CheckManually`, or `NoControls` (the batch has no positive or no negative controls). |
| **sample_type**              | `positive`, `negative`, `sample`, or `NA`, from the manifest.                                     |
| **batch**                    | Batch, from the manifest.                                                                         |
| **parasites_per_ul**         | Parasitemia, from the manifest.                                                                   |
| **sequencing_run**           | Sequencing run, from the manifest.                                                                |

### 03_ExtractDrugResistanceMarkers

Translates amplicon sequences at loci of interest into amino acid calls, then estimates single-locus and multi-locus resistance allele frequencies.

##### Inputs:

| Input name | Description | Type | Required | Default |
|---|---|---|---|---|
| **filtered_allele_data** | Allele table of microhaplotypes — the `filtered_allele_data` output of `02_AmpliconPanelQcReport`. Converted internally to the pipeline's specimen/target/reads/seq format. | File | Yes | - |
| **amplicon_info** | Amplicon info table with `target_name`, `chrom`, `insert_start` and `insert_end` columns; used to build the panel BED. | File | Yes | - |
| **reference** | Reference FASTA of insert sequences, one record per `target_name`. | File | Yes | - |
| **loci_of_interest_bed** | BED of loci of interest; single-locus estimates are computed at these loci. Preconfigured to `gs://broad-malaria-public/mad4hatter_workspace_data/default_principal_resistance_marker_info_table.bed`. | File | Yes | preconfigured |
| **loci_groups** | TSV/CSV defining multi-locus groups; multi-locus estimates are computed for these groups. Preconfigured to `gs://broad-malaria-public/mad4hatter_workspace_data/default_loci_groups.tsv`. | File | Yes | preconfigured |
| **billing_project** | Terra billing project of the workspace whose data table is updated. Optional — may be left empty. | String? | No | (detected) |
| **workspace_name** | Name of the Terra workspace whose data table is updated. Optional — may be left empty. | String? | No | (detected) |
| **sample_table** | Terra data table the resmarker columns are written to. Optional — may be left empty. The row id column is always `<sample_table>_id`. | String? | No | (detected) |
| **workspace_bucket** | Workspace bucket id (e.g. `fc-…`, no `gs://`). Optional — may be left empty. | String? | No | (detected) |
| **pmo** | PMO JSON file. | File? | No | - |
| **population_assignment** | TSV/CSV mapping `specimen_name` to `population`; enables per-population results. | File? | No | - |
| **pmo_population_fields** | Comma-separated PMO specimen metadata fields used to build the population label; used only when `pmo` is given and `population_assignment` is not. | String? | No | - |
| **pmo_population_separator** | Join string used when building the population label from `pmo_population_fields`. | String | No | `_` |
| **population_label** | Population label used when no population assignment is available; it becomes the population name in `ml_summary` / `sl_summary`. Left blank in this workspace, so the default applies. Set it to `this.<your_table>_set_id` if you would rather the summaries be labelled by set name — but that expression names one table, so it has to change per panel. | String | No | pop1 |
| **targeted_reference** | FASTA containing only the targets (PMO mode); preferred over `genome_reference` if both are given. | File? | No | - |
| **genome_reference** | FASTA containing the full genome (PMO mode). | File? | No | - |
| **mlaf_method** | Multi-locus allele frequency method: `naive`, `MLBM` or `FEM`. | String | No | naive |
| **naive_mlaf_method** | Method passed to the naive multi-locus estimator. | String | No | wsaf_prop |
| **slaf_method** | Single-locus allele frequency method: `naive`, `IDM` or `mhaps_freq`. | String | No | naive |
| **naive_slaf_method** | Method passed to the naive single-locus estimator. | String | No | read_count_prop |
| **translate_loci_extra_args** | Extra arguments passed to `translate_loci_of_interest`. | String | No | `""` |
| **outdir** | Output directory name; letters, numbers, `_` and `-` only. | String | No | output |
| **docker_image** | Docker image used by the pipeline tasks. | String | No | plasmogenepi/plasmodiumdrugres:wdl |

Advanced, task-level overrides also exist and should be left empty under normal use: `t_000_terra_env.namespace` / `t_000_terra_env.workspace` (force the detected workspace), `convert_allele_table.docker_image`, `make_panel_bed.docker_image`, `resmarkers_to_terra.docker_image` (all default to `us.gcr.io/broad-dsp-lrma/mad4hatter-drugres-python:latest`), plus per-task tuning on the single-locus estimators (`t_slaf_other.*`, `t_slaf_mhaps.*`).

##### Outputs:

These outputs are **GCS paths as `String`s**, staged into `gs://<workspace-bucket>/<outdir>/<timestamp>/`.

| Output Name | Description | Type |
|---|---|---|
| **ml_summary** | Multi-locus allele frequency summary | String |
| **sl_summary** | Single-locus allele frequency summary | String |
| **sl_from_ml_summary** | Single-locus frequencies derived from the multi-locus estimates | String |
| **amino_acid_calls** | Per-specimen amino acid calls at the loci of interest | String |
| **collapsed_amino_acid_calls** | Amino acid calls collapsed per specimen, gene and position | String |
| **loci_covered_by_target_samples_info** | Sample-level information on which loci of interest are covered. **Use this to tell "not assayed" from "assayed and reference".** | String |
| **loci_of_interest_for_target_for_microhap** | Mapping of loci of interest to targets/microhaplotypes | String |

##### Writes directly into data tables:

For each specimen, the workflow adds one column to `sample_table` for every gene and amino acid position it calls, named `resmarker_{gene}_{aa_position}`:

| Column | Description |
|---|---|
| **resmarker_&lt;gene&gt;_&lt;aa_position&gt;** | That specimen's amino acid call at the position, e.g. `resmarker_dhfr-ts_164`. Mixed calls are the distinct values sorted and joined with `/`, e.g. `F/Y`. One column per called gene/position, so this can add many columns. |

## Columns written directly into your data tables

Two of these workflows write into your data tables as a side effect, over the Terra API, in addition to the files they return through output mappings. These columns do **not** appear in the workflow's output list, so they are easy to miss.

| Source | Table written | Columns |
|---|---|---|
| `01_Mad4Hatter` / `01_PfPhast` | none | — |
| `02_AmpliconPanelQcReport` | per-sample table (`sample_table`) | `Library_sample_name`, `Library_sample_qc_status`, `mean_prop_good_loci`, `postprocessed_read_count`, `batch_pass`, `sample_type`, `batch`, `parasites_per_ul`, `sequencing_run` |
| `03_ExtractDrugResistanceMarkers` | per-sample table (`sample_table`) | `resmarker_<gene>_<aa_position>`, one per called gene/position |

Three things to know about these writes:

1. **They are upserts, and they never clear.** Rows with a matching row id are updated; other rows and columns are left unchanged. A value sitting in a `resmarker_*` column may therefore be from an earlier run where that locus was covered — a later run with dropout will not blank it.
2. **A blank `resmarker_*` cell means "no call", not "wild type".** Reference-matching positions are reported explicitly with their amino acid letter, so an empty cell means the specimen had no observed allele at that target, typically amplicon dropout or reads removed by the upstream filters. Use `loci_covered_by_target_samples_info` to distinguish the two.
3. **Four of the `02` columns come from your manifest**, not from the QC computation: `sample_type`, `batch`, `parasites_per_ul` and `sequencing_run`. If your table already holds the same facts under different names, you will end up with both.

## Contact info
If you have questions about the workflows please reach out to kathryn.murie@ucsf.edu \
If you have questions about Terra please reach out to publichealthgenomics@broadinstitute.org

## Citation
