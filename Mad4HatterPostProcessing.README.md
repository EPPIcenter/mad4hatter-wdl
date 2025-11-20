# Mad4HatterPostProcessing

This workflow runs postprocessing _only_.

### Inputs:

| Input Name                   | Description                                                                                                        | Type          | Required | Default                       |
|------------------------------|--------------------------------------------------------------------------------------------------------------------|---------------|----------|-------------------------------|
| **pools**                    | The names of the pools.                                                                                            | Array[String] | Yes      | -                             |
| **amplicon_info_files**      | The TSVs that contain amplicon information.                                                                        | Array[File]   | Yes      | -                             |
| **clusters**                 | The clusters file.                                                                                                 | File          | Yes      | -                             |
| **just_concatenate**         | Whether non-overlaps should be concatenated. Optional.                                                             | Boolean       | No       | true                          |
| **mask_tandem_repeats**      | Whether tandem repeats should be masked. Optional.                                                                 | Boolean       | No       | true                          |
| **mask_homopolymers**        | Whether homopolymers should be masked. Optional.                                                                   | Boolean       | No       | true                          |
| **amplicon_info_files**      | Amplicon info files. Used to be make concatenated amplicon info file.                                              | Array[File]   | No       | -                             |
| **targeted_reference_files** | Targeted reference files. Will be used to create reference.fasta                                                   | Array[File]   | No       | -                             |
| **refseq_fasta**             | Path to reference sequences (optional, auto-generated if not provided. If not provided genome must be provided)    | File          | No       | -                             |
| **genome**                   | Path to genome file. (optional, but one of genome or refseq_fasta must be provided)                                | File          | No       | -                             |
| **masked_fasta**             | The masked fasta file. Optional.                                                                                   | File          | No       | -                             |
| **docker_image**             | Specifies a custom Docker image to use. Optional.                                                                  | String        | No       | eppicenter/mad4hatter:develop |

### Outputs:

| Output Name         | Description                                         | Type |
|---------------------|-----------------------------------------------------|------|
| **amplicon_info**   | The processed amplicon info file                    | File |
| **reference_fasta** | The postprocessed reference FASTA file              | File |
| **alleledata**      | The final allele table after postprocessing         | File |
