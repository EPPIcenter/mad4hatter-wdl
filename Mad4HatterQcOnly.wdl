version 1.0

import "workflows/generate_amplicon_info.wdl" as GenerateAmpliconInfo
import "workflows/qc_only.wdl" as QcOnly
import "modules/local/get_amplicon_and_targeted_ref_from_config.wdl" as GetAmpliconAndTargetedRefFromConfig

workflow Mad4HatterQcOnly {
    input {
        Array[String] pools
        Array[File]? amplicon_info_files
        Array[File] forward_fastqs
        Array[File] reverse_fastqs
        String sequencer
        Int cutadapt_minlen = 100
        Int allowed_errors = 0
        # TODO: Pin the specific docker image version here when first release is ready
        String docker_image = "eppicenter/mad4hatter:develop"
    }

    File pool_options_json = "/opt/mad4hatter/conf/terra_panel.json" # Optional custom pool options JSON file. Needs to be on docker image.

    Boolean amplicon_files_provided = defined(amplicon_info_files)
    if (!amplicon_files_provided) {
        call GetAmpliconAndTargetedRefFromConfig.get_amplicon_and_targeted_ref_from_config {
            input:
                pools = pools,
                pool_options_json = pool_options_json,
                docker_image = docker_image
        }
    }

    # Determine final amplicon info files to use. If provided, use those; otherwise, use from config.
    Array[File] amplicon_info_files_final = select_first([amplicon_info_files, get_amplicon_and_targeted_ref_from_config.amplicon_info_files])

    call GenerateAmpliconInfo.generate_amplicon_info {
        input:
            pools = pools,
            docker_image = docker_image,
            amplicon_info_files = amplicon_info_files_final
    }

    call QcOnly.qc_only {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            forward_fastqs = forward_fastqs,
            reverse_fastqs = reverse_fastqs,
            sequencer = sequencer,
            cutadapt_minlen = cutadapt_minlen,
            allowed_errors = allowed_errors,
            docker_image = docker_image
    }

    output {
        File amplicon_info = generate_amplicon_info.amplicon_info_ch
        File amplicon_coverage = qc_only.sample_coverage_out
        File sample_coverage = qc_only.amplicon_coverage_out
    }
}