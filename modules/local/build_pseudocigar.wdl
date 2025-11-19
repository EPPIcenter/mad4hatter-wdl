version 1.0

task build_pseudocigar {
    input {
        File alignments
        Int cpus = 1
        String docker_image
    }

    command <<<
        Rscript /opt/mad4hatter/bin/build_pseudocigar.R \
            --alignments ~{alignments} \
            --ncores ~{cpus}
    >>>

    output {
        File pseudocigar = "alignments.pseudocigar.txt"
    }

    runtime {
        docker: docker_image
        cpu: cpus
    }
}