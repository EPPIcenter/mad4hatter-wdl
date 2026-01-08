version 1.0

import "../../modules/local/build_resources.wdl" as build_resources

workflow concatenate_targeted_reference {
    input {
        Array[File] reference_input_paths
        String docker_image
    }

    call build_resources.build_targeted_reference {
        input:
            reference_input_paths = reference_input_paths,
            docker_image = docker_image
    }

    output {
        File reference_fasta = build_targeted_reference.reference_fasta
    }
}

