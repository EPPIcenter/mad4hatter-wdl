# Mad4HatterQcOnly

This workflow runs quality control _only_ on the selected samples.

### Inputs: 

| Input Name              | Description                                                           | Type          | Required | Default                       |
|-------------------------|-----------------------------------------------------------------------|---------------|----------|-------------------------------|
| **pools**               | The names of the pools.                                               | Array[String] | Yes      | -                             |
| **amplicon_info_files** | The TSVs that contain amplicon information.                           | Array[File]   | Yes      | -                             |
| **forward_fastqs**      | List of forward fastqs. Must be in correct order.                     | Array[File]   | Yes      | -                             |
| **reverse_fastqs**      | List of reverse fastqs. Must be in correct order.                     | Array[File]   | Yes      | -                             |
| **cutadapt_minlen**     | The minimum length used for cutadapt. Optional.                       | Int           | No       | 100                           |
| **gtrim**               | If true, --nextseq-trim will be used to trim trailing G in cutadapt.  | Bool          | No       | false                         |
| **quality_score**       | The quality score threshold to apply in cutadapt.                     | Int           | No       | 20                            |
| **allowed_errors**      | The number of errors allowed to be encountered in cutadapt. Optional. | Int           | No       | 0                             |
| **docker_image**        | Specifies a custom Docker image to use. Optional.                     | String        | No       | eppicenter/mad4hatter:develop |

### Outputs:

| Output Name             | Description                                        | Type |
|-------------------------|----------------------------------------------------|------|
| **amplicon_info**       | The processed amplicon info file                   | File |
| **amplicon_coverage**   | The sample coverage file (from QC)                 | File |
| **sample_coverage**     | The amplicon coverage file (from QC)               | File |
