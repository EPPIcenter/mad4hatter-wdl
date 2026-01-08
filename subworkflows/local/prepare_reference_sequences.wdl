version 1.0

# This workflow allows users to optionally create a reference from genomes or use a default
import "../../modules/local/create_reference_from_genomes.wdl" as create_reference_from_genomes
import "../../subworkflows/local/concatenate_targeted_reference.wdl" as concatenate_targeted_reference
import "../../modules/local/error_with_message.wdl" as error_with_message

workflow prepare_reference_sequences {
    input {
        File amplicon_info_ch
        File? genome
        Array[File]? targeted_reference_files
        Boolean mask_tandem_repeats = true
        Int trf_min_score = 25
        Int trf_max_period = 3
        Boolean mask_homopolymers = true
        Int homopolymer_threshold = 5
        String docker_image
    }

    # Validate that exactly one of genome or targeted_reference_files is provided
    Boolean invalid = (defined(genome) && defined(targeted_reference_files)) || (!defined(genome) && !defined(targeted_reference_files))

    if (invalid) {
        call error_with_message.error_with_message {
            input:
                message = "Error: Exactly one of 'genome' or 'targeted_reference_files' must be provided."
        }
    }

    if (defined(genome)) {
        File defined_genome_path = select_first([genome])

        call create_reference_from_genomes.create_reference_from_genomes {
            input:
                genome = defined_genome_path,
                amplicon_info_ch = amplicon_info_ch,
                docker_image = docker_image,
        }
    }

  if (!defined(genome)) {
    Array[File] defined_reference_input_paths = select_first([targeted_reference_files])
    call concatenate_targeted_reference.concatenate_targeted_reference {
      input:
        reference_input_paths = defined_reference_input_paths,
        docker_image = docker_image
    }
  }

  output {
    File reference_fasta = select_first([
      concatenate_targeted_reference.reference_fasta,
      create_reference_from_genomes.reference_fasta
    ])
  }
}