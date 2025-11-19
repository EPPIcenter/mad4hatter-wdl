version 1.0

import "demultiplex_amplicons.wdl" as demultiplex_amplicons
import "quality_control.wdl" as quality_control

# This workflow is meant to drive quality control of amplicon sequencing data
workflow qc_only {
    input {
        File amplicon_info_ch
        Array[File] forward_fastqs
        Array[File] reverse_fastqs
        String sequencer
        Int cutadapt_minlen
        Int allowed_errors
        String docker_image
    }

    call demultiplex_amplicons.demultiplex_amplicons {
        input:
            amplicon_info_ch = amplicon_info_ch,
            forward_fastqs = forward_fastqs,
            reverse_fastqs = reverse_fastqs,
            sequencer = sequencer,
            cutadapt_minlen = cutadapt_minlen,
            allowed_errors = allowed_errors,
            docker_image = docker_image
    }

    call quality_control.quality_control {
        input:
            amplicon_info_ch = amplicon_info_ch,
            sample_coverage_files = demultiplex_amplicons.sample_summary_ch,
            amplicon_coverage_files = demultiplex_amplicons.amplicon_summary_ch,
            docker_image = docker_image
    }

    output {
        File sample_coverage_out = quality_control.sample_coverage
        File amplicon_coverage_out = quality_control.amplicon_coverage
    }
}

