version 1.0

task build_alleletable {
    input {
        File amplicon_info_ch
        File denoised_asvs
        File processed_asvs
        String docker_image
    }

    command <<<
        Rscript /opt/mad4hatter/bin/build_alleletable.R \
            --amplicon-info ~{amplicon_info_ch} \
            --denoised-asvs ~{denoised_asvs} \
            --processed-asvs ~{processed_asvs}
    >>>

    output {
        File alleledata = "allele_data.txt"
    }

    runtime {
        docker: docker_image
    }
}