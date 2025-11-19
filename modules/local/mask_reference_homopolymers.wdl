version 1.0

task mask_reference_homopolymers {
    input {
        File refseq_fasta
        Int homopolymer_threshold
        String docker_image
    }

    command <<<
        set -euo pipefail

        Rscript /opt/mad4hatter/bin/mask_homopolymers.R \
            --refseq-fasta ~{refseq_fasta} \
            --homopolymer_threshold ~{homopolymer_threshold}
    >>>

    output {
        File masked_fasta = glob("*.mask")[0]
    }

    runtime {
        docker: docker_image
    }
}