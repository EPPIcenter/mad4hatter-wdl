version 1.0

import "../modules/local/dada2_analysis.wdl" as dada2_analysis

workflow denoise_amplicons_1 {
    input {
        File amplicon_info_ch
        Array[File] demultiplexed_dir_tars
        String dada2_pool
        Int band_size
        Float omega_a
        Int max_ee
        Boolean just_concatenate
        Int additional_memory
        String? dada2_runtime_size
        String docker_image
    }

    call dada2_analysis.dada2_analysis {
        input:
            demultiplexed_dir_tars = demultiplexed_dir_tars,
            amplicon_info_ch = amplicon_info_ch,
            dada2_pool = dada2_pool,
            band_size = band_size,
            omega_a = omega_a,
            max_ee = max_ee,
            just_concatenate = just_concatenate,
            additional_memory = additional_memory,
            dada2_runtime_size = dada2_runtime_size,
            docker_image = docker_image,
    }

    output {
        File dada2_clusters = dada2_analysis.dada2_clusters
    }
}