version 1.0

import "../modules/local/create_primer_files.wdl" as create_primer_files
import "../modules/local/cutadapt.wdl" as cutadapt

workflow demultiplex_amplicons {
    input {
        File amplicon_info_ch
        Array[File] forward_fastqs
        Array[File] reverse_fastqs
        String sequencer
        Int cutadapt_minlen
        Int allowed_errors
        String docker_image
    }

    Array[Pair[File, File]] read_pairs = zip(forward_fastqs, reverse_fastqs)

    call create_primer_files.create_primer_files {
        input:
            amplicon_info_ch = amplicon_info_ch,
            docker_image = docker_image
    }

    scatter (read_pair in read_pairs) {
        call cutadapt.cutadapt {
            input:
                fwd_primers = create_primer_files.fwd_primers,
                rev_primers = create_primer_files.rev_primers,
                forward_fastq = read_pair.left,
                reverse_fastq = read_pair.right,
                cutadapt_minlen = cutadapt_minlen,
                sequencer = sequencer,
                allowed_errors = allowed_errors,
                docker_image = docker_image
        }
    }

    output {
        Array[File] sample_summary_ch = cutadapt.sample_summary
        Array[File] amplicon_summary_ch = cutadapt.amplicon_summary
        Array[File] demux_fastqs_ch = cutadapt.demultiplexed_fastqs
    }
}