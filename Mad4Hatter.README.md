# MAD4HatTeR Pipeline Parameters

This workflow runs the entire MAD4HatTeR pipeline, processing amplicon sequencing FASTQ data to produce allele tables, resistance markers, and other outputs.

## Input Parameters

| Input Name               | Description                                                                                                                      | Type          | Required | Default                       |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------|---------------|----------|-------------------------------|
| pools                    | List of pool or panel names. Options: MAD4HatTeR ["D1.1","R1.1","R2.1","R1.2","v1","v2"], PfPHAST ["M1.1","M2.1","M1.addon"], Other ["4cast","ama1"] | Array[String] | Yes      | -                             |
| sequencer                | The sequencer used to produce your data [Options: miseq, nextseq]                                                                                      | String        | Yes      | -                             |
| forward_fastqs           | List of forward FASTQ files. Order must match reverse_fastqs                                                                                           | Array[File]   | Yes      | -                             |
| reverse_fastqs           | List of reverse FASTQ files. Order must match forward_fastqs                                                                                           | Array[File]   | Yes      | -                             |
| output_directory         | Folder name for outputs                                                                                                                               | String        | Yes      | -                             |
| amplicon_info_files      | Amplicon info file(s) to define the panel information. If not provided then the pre-defined panel info for the pools will be used.                      | Array[File]   | No       | -                             |
| targeted_reference_files | Targeted reference file(s). If not provided then the pre-defined reference sequences for the pools will be used.                                        | Array[File]   | No       | -                             |
| refseq_fasta             | Path to targeted reference sequences. If not provided then the pre-defined reference sequences for the pools will be used.                | File          | No       | -                             |
| genome                   | Path to genome file. If not provided then the pre-defined reference sequences for the pools will be used.                                          | File          | No       | -                             |
| omega_a                  | Level of statistical evidence required for DADA2 to infer a new ASV                                                              | Float         | No       | 0.000...
001                 |
| dada2_pool               | Pooling method for DADA2 to process ASVs                                                                                         | String        | No       | pseudo                        |
| band_size                | Limit on net cumulative number of insertions in DADA2                                                                            | Int           | No       | 16                            |
| max_ee                   | Limit on number of expected errors within a read in DADA2                                                                        | Int           | No       | 3                             |
| cutadapt_minlen          | Minimum length for cutadapt                                                                                                      | Int           | No       | 100                           |
| allowed_errors           | Allowed errors for cutadapt                                                                                                      | Int           | No       | 0                             |
| just_concatenate         | If true, just concatenate reads                                                                                                  | Boolean       | No       | false                         |
| mask_tandem_repeats      | Mask tandem repeats                                                                                                              | Boolean       | No       | true                          |
| mask_homopolymers        | Mask homopolymers                                                                                                                | Boolean       | No       | true                          |
| masked_fasta             | Masked FASTA file                                                                                                                | File          | No       | -                             |
| principal_resmarkers     | Principal resistance markers file                                                                                                | File          | No       | -                             |
| resmarkers_info_tsv      | Resistance markers info TSV file                                                                                                 | File          | No       | -                             |
| dada2_additional_memory  | Additional memory (in GB) to be added to the provided memory used in the DADA2 runtime configuration                            | Int           | No       | 0                             |
| dada2_runtime_size       | DADA2 runtime size [small, medium, large]. Should be based on the size of the input dataset. Will be calculated if not provided | String        | No       | -                             |
| docker_image             | The Docker image to use                                                                                                          | String        | No       | eppicenter/mad4hatter:develop |

## Pipeline Outputs
For more information about the pipeline outputs [see here](https://eppicenter.github.io/mad4hatter/docs/pipeline-outputs/).

| Output Name                      | Description                                                                                  | Type   |
|----------------------------------|----------------------------------------------------------------------------------------------|--------|
| final_allele_table_cloud_path    | Path to the final allele table in the cloud output directory                                 | String |
| sample_coverage_cloud_path       | Path to the sample coverage file in the cloud output directory                               | String |
| amplicon_coverage_cloud_path     | Path to the amplicon coverage file in the cloud output directory                             | String |
| dada2_clusters_cloud_path        | Path to the DADA2 clusters file in the cloud output directory                                | String |
| resmarkers_output_cloud_path     | Path to the resistance markers output file in the cloud output directory                     | String |
| resmarkers_by_locus_cloud_path   | Path to the resistance markers by locus file in the cloud output directory                   | String |
| microhaps_cloud_path             | Path to the microhaplotypes file in the cloud output directory                               | String |
| new_mutations_cloud_path         | Path to the new mutations file in the cloud output directory                                 | String |
| amplicon_info_cloud_path         | Path to the amplicon info file in the cloud output directory                                 | String |
| reference_fasta_cloud_path       | Path to the reference FASTA file in the cloud output directory                               | String |
| resmarkers_file_cloud_path       | Path to the resistance markers file in the cloud output directory                            | String |
