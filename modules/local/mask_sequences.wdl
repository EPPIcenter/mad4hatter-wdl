version 1.0

task mask_sequences {
    input {
        Array[File] masks
        File alignments
        Int cpus = 1
        String docker_image
    }

    command <<<
        Rscript /opt/mad4hatter/bin/mask_sequences.R \
            --masks ~{sep=" " masks} \
            --alignments ~{alignments} \
            --n-cores ~{cpus}
    >>>

    output {
        File masked_alignments = "masked.alignments.txt"
    }

    runtime {
        docker: docker_image
        cpu: cpus
    }
}



