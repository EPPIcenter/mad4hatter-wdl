version 1.0

task align_to_reference_and_filter_asvs {
    input {
        File clusters
        File refseq_fasta
        File amplicon_info_ch
        Int cpus = 1
        String docker_image
    }

    # Pulled default value from https://github.com/EPPIcenter/mad4hatter/blob/0fdf688d8bef6b1407de66ed2644a2d26635015d/nextflow.config#L32
    Int alignment_threshold = 60

    command <<<
        set -euo pipefail
        echo "Running align_to_reference.R"
        Rscript /opt/mad4hatter/bin/align_to_reference.R \
            --clusters ~{clusters} \
            --refseq-fasta ~{refseq_fasta} \
            --amplicon-table ~{amplicon_info_ch} \
            --n-cores ~{cpus}

        echo "Running filter_asv_process.sh"
        bash /opt/mad4hatter/bin/filter_asv_process.sh \
            -i alignments.txt \
            -o filtered.alignments.txt \
            -t ~{alignment_threshold}
    >>>

    output {
        File alignments = "alignments.txt"
        File filtered_alignments_ch = "filtered.alignments.txt"
    }

    runtime {
        docker: docker_image
        memory: "4 GB"
        cpu: cpus
    }
}