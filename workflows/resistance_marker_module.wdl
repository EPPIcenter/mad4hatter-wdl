version 1.0

import "../modules/local/build_resmarker_info_and_resistance_table.wdl" as build_resmarker_info_and_resistance_table

# This workflow is comprised of processes to build a table of resistance markers of interest.
workflow resistance_marker_module {
    input {
        File allele_data
        File alignment_data
        File reference
        File amplicon_info_ch
        File? principal_resmarkers
        File? resmarkers_info_tsv
        String docker_image
    }

    call build_resmarker_info_and_resistance_table.build_resmarker_info_and_resistance_table {
        input:
            alleledata = allele_data,
            alignment_data = alignment_data,
            refseq = reference,
            amplicon_info_ch = amplicon_info_ch,
            principal_resmarkers = principal_resmarkers,
            resmarkers_info_tsv = resmarkers_info_tsv,
            docker_image = docker_image
    }

    output {
        File resmarkers_output = build_resmarker_info_and_resistance_table.resmarkers_output
        File resmarkers_by_locus = build_resmarker_info_and_resistance_table.resmarkers_by_locus
        File microhaps = build_resmarker_info_and_resistance_table.microhaps
        File new_mutations = build_resmarker_info_and_resistance_table.new_mutations
        File resmarkers_file = build_resmarker_info_and_resistance_table.resmarkers_file
    }
}