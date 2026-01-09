version 1.0

import "../modules/local/build_resources.wdl" as build_resources

workflow generate_amplicon_info {
    input {
        Array[File] amplicon_info_files
        Array[String] pools
        String docker_image
    }

    call build_resources.build_amplicon_info {
        input:
            pools = pools,
            amplicon_info_files = amplicon_info_files,
            docker_image = docker_image
    }

    output {
        File amplicon_info_ch = build_amplicon_info.amplicon_info_ch
    }
}

