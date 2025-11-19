version 1.0

task build_amplicon_info {
    input {
        Array[String] pools
        Array[File] amplicon_info_files
        String? amplicon_info_output = "amplicon_info.tsv"
        String docker_image
    }

    command <<<
        python3 /opt/mad4hatter/bin/build_amplicon_info.py \
        --pools ~{sep=' ' pools} \
        --amplicon_info_paths ~{sep=' ' amplicon_info_files} \
        --amplicon_info_output_path ~{amplicon_info_output}
    >>>

    output {
        File amplicon_info_ch = "~{amplicon_info_output}"
    }

    runtime {
        docker: docker_image
    }
}

task build_targeted_reference {
    input {
        Array[File] reference_input_paths
        String? reference_output_path = "reference.fasta"
        String docker_image
    }

    command <<<
        python3 /opt/mad4hatter/bin/merge_fasta.py \
            --reference_paths ~{sep=' ' reference_input_paths} \
            --reference_output_path ~{reference_output_path}
    >>>

    output {
        File reference_fasta = "~{reference_output_path}"
    }

    runtime {
        docker: docker_image
    }
}