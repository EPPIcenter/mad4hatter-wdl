version 1.0

task create_reference_from_genomes {
    input {
        File genome
        File amplicon_info_ch
        String refseq_fasta = "reference.fasta"
        Int cpus = 1
        String docker_image
    }

    command <<<
        Rscript /opt/mad4hatter/bin/create_reference_from_genomes.R \
            --ampliconFILE ~{amplicon_info_ch} \
            --genome ~{genome} \
            --output ~{refseq_fasta} \
            --ncores ~{cpus}
    >>>

    output {
        File reference_fasta = refseq_fasta
    }

    runtime {
        docker: docker_image
        cpu: cpus
    }
}