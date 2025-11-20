version 1.0

import "workflows/process_inputs.wdl" as ProcessInputs
import "workflows/postproc_only.wdl" as PostProc
import "modules/local/get_amplicon_and_targeted_ref_from_config.wdl" as GetAmpliconAndTargetedRefFromConfig
import "modules/local/error_with_message.wdl" as ErrorWithMessage

workflow Mad4HatterPostProcessing {
    input {
        Array[String] pools
        Array[File]? amplicon_info_files
        Array[File]? targeted_reference_files
        File? refseq_fasta # Path to reference sequences (optional, auto-generated if not provided)
        File? genome
        File clusters
        Boolean just_concatenate = true
        Boolean mask_tandem_repeats = true
        Boolean mask_homopolymers = true
        File? masked_fasta
        File pool_options_json = "/opt/mad4hatter/conf/terra_panel.json" # Optional custom pool options JSON file. Needs to be on docker image.
        # TODO: Pin the specific docker image version here when first release is ready
        String docker_image = "eppicenter/mad4hatter:develop"
    }

    # Check that either one of genome or refseq_fasta is provided or nothing is provided (then refseq_fasta is auto-generated)
    Boolean both_genome_and_refseq_provided = defined(genome) && defined(refseq_fasta)
    if (both_genome_and_refseq_provided) {
        call ErrorWithMessage.error_with_message {
            input:
                message = "Error: Either one of 'genome' or 'refseq_fasta' is provided or nothing is provided."
        }
    }

    # Check if either amplicon_info_files or targeted_reference_files
    Boolean either_amplicon_info_or_targeted_ref_provided = defined(amplicon_info_files) || defined(targeted_reference_files)
    if (!either_amplicon_info_or_targeted_ref_provided) {
        # If neither is provided then get it from config on docker image
        call GetAmpliconAndTargetedRefFromConfig.get_amplicon_and_targeted_ref_from_config {
            input:
                pools = pools,
                pool_options_json = pool_options_json,
                docker_image = docker_image
        }
    }

    # Determine final amplicon info files to use. If provided, use those; otherwise, use from config.
    Array[File] amplicon_info_files_final = select_first([amplicon_info_files, get_amplicon_and_targeted_ref_from_config.amplicon_info_files])
    Array[File]? targeted_reference_files_final = select_first([targeted_reference_files, get_amplicon_and_targeted_ref_from_config.targeted_reference_files])

    call ProcessInputs.generate_amplicon_info {
        input:
            pools = pools,
            docker_image = docker_image,
            amplicon_info_files = amplicon_info_files_final
    }

    call PostProc.postproc_only {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            clusters = clusters,
            just_concatenate = just_concatenate,
            mask_tandem_repeats = mask_tandem_repeats,
            mask_homopolymers = mask_homopolymers,
            refseq_fasta = refseq_fasta,
            targeted_reference_files = targeted_reference_files_final,
            genome = genome,
            masked_fasta = masked_fasta,
            docker_image = docker_image
    }

    output {
        File amplicon_info = generate_amplicon_info.amplicon_info_ch
        File reference_fasta = postproc_only.reference_ch
        File alleledata = postproc_only.alleledata
    }
}