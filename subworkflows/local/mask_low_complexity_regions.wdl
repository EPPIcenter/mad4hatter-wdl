version 1.0

import "../../modules/local/mask_reference_tandem_repeats.wdl" as mask_reference_tandem_repeats
import "../../modules/local/mask_reference_homopolymers.wdl" as mask_reference_homopolymers
import "../../modules/local/mask_sequences.wdl" as mask_sequences


# This workflow allows users to optionally mask homopolymers and / or tandem repeats
workflow mask_low_complexity_regions {
    input {
        File reference
        # Got default values from https://github.com/EPPIcenter/mad4hatter/blob/develop/nextflow.config
        Boolean mask_tandem_repeats = true
        Int trf_min_score = 25
        Int trf_max_period = 3
        Boolean mask_homopolymers = true
        Int homopolymer_threshold = 5
        File alignments
        String docker_image
    }

    if (mask_tandem_repeats) {
        call mask_reference_tandem_repeats.mask_reference_tandem_repeats {
            input:
                refseq_fasta = reference,
                min_score = trf_min_score,
                max_period = trf_max_period,
                docker_image = docker_image
        }
    }

    if (mask_homopolymers) {
        call mask_reference_homopolymers.mask_reference_homopolymers {
            input:
                refseq_fasta = reference,
                homopolymer_threshold = homopolymer_threshold,
                docker_image = docker_image
        }
    }

    # Collect whichever masked references exist
    Array[File] masked_references = select_all([
        mask_reference_tandem_repeats.masked_fasta,
        mask_reference_homopolymers.masked_fasta
    ])

    call mask_sequences.mask_sequences {
        input:
            masks = masked_references,
            alignments = alignments,
            docker_image = docker_image
    }

    output {
        File masked_alignments = mask_sequences.masked_alignments
    }
}

