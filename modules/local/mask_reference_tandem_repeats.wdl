version 1.0

task mask_reference_tandem_repeats {
    input {
        File refseq_fasta
        Int min_score
        Int max_period
        String docker_image
    }

    command <<<
        set -euo pipefail

        # Name the input file to a standard name so outputs are predictable
        mv ~{refseq_fasta} reference.fasta
        trf reference.fasta 2 7 7 80 10 ~{min_score} ~{max_period} -h -m
    >>>

    output {
        File masked_fasta = "reference.fasta.2.7.7.80.10.~{min_score}.~{max_period}.mask"
    }

    runtime {
        docker: docker_image
    }
}