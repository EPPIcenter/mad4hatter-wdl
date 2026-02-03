version 1.0

task build_alleletable {
    input {
        File amplicon_info_ch
        File denoised_asvs
        File masked_pseudocigar_table
        File unmasked_pseudocigar_table
        File masked_asv_table
        String docker_image
    }

    command <<<
        Rscript /opt/mad4hatter/bin/build_alleletable.R \
            --amplicon-info ~{amplicon_info_ch} \
            --denoised-asvs ~{denoised_asvs} \
            --masked-pseudocigar-table ~${masked_pseudocigar_table} \
            --unmasked-pseudocigar-table ~${unmasked_pseudocigar_table} \
            --masked-asv-table ~${masked_asv_table}
    >>>

    output {
        File alleledata = "allele_data.txt"
        File alleledata_collapsed = "allele_data_collapsed.txt"
    }

    runtime {
        docker: docker_image
    }
}