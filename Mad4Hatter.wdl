version 1.0

import "workflows/demultiplex_amplicons.wdl" as DemultiplexAmpliconsWf
import "workflows/denoise_amplicons_1.wdl" as DenoiseAmplicons1Wf
import "workflows/denoise_amplicons_2.wdl" as DenoiseAmplicons2Wf
import "workflows/resistance_marker_module.wdl" as ResistanceMarkerModuleWf
import "workflows/quality_control.wdl" as QualityControlWf
import "workflows/process_inputs.wdl" as ProcessInputsWf
import "modules/local/build_alleletable.wdl" as BuildAlleletable
import "modules/local/move_outputs.wdl" as MoveOutputs
import "modules/local/get_amplicon_and_targeted_ref_from_config.wdl" as GetAmpliconAndTargetedRefFromConfig
import "modules/local/error_with_message.wdl" as ErrorWithMessage

## MAD4HatTeR Main Workflow
##
## This is the main workflow for MAD4HatTeR (Malaria Amplicon Deep-sequencing for Haplotype and Target Resistance)
## pipeline. It processes amplicon sequencing data through demultiplexing, denoising, quality control,
## and resistance marker analysis.


workflow MAD4HatTeR {
    input {
        Array[String] pools
        String sequencer # The sequencer used to produce your data
        Array[File] forward_fastqs # List of forward fastqs. Must be in correct order.
        Array[File] reverse_fastqs # List of reverse fastqs. Must be in correct order.
        Array[File]? amplicon_info_files
        Array[File]? targeted_reference_files
        File? refseq_fasta # Path to targeted reference sequences (optional, auto-generated if not provided)
        File? genome
        Float omega_a = 0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001 # Level of statistical evidence required for DADA2 to infer a new ASV
        String dada2_pool = "pseudo" # Pooling method for DADA2 to process ASVs [Options: pseudo (default), true, false]
        Int band_size = 16 # Limit on the net cumulative number of insertions of one sequence relative to the other in DADA2
        Int max_ee = 3 # Limit on number of expected errors within a read during filtering and trimming within DADA2
        Int cutadapt_minlen = 100
        Int allowed_errors = 0
        Boolean just_concatenate = false
        Boolean mask_tandem_repeats = true
        Boolean mask_homopolymers = true
        File? masked_fasta
        File? principal_resmarkers
        File? resmarkers_info_tsv
        File pool_options_json = "/opt/mad4hatter/conf/terra_panel.json" # Optional custom pool options JSON file. Needs to be on docker image.
        String output_cloud_directory
        Int dada2_additional_memory = 0
        String? dada2_runtime_size
        # TODO: Pin the specific docker image version here when first release is ready
        String docker_image = "eppicenter/mad4hatter:develop"
    }

    # Use sub() with a regular expression to check for the prefix.
    # This pattern matches the entire string if it starts with "gs://".
    # If the pattern is found, a non-empty string is returned.
    # If the pattern is not found, the original string is returned.
    String matches_prefix = sub(output_cloud_directory, "^gs://.*", "MATCH")

    # Use a boolean variable to convert the string result to a boolean.
    # "MATCH" will be true, while any other string will be false.
    Boolean starts_with_gs = matches_prefix == "MATCH"

    # Use a conditional call to execute the ErrorWithMessage task
    # if the condition is false.
    if (!starts_with_gs) {
        call ErrorWithMessage.error_with_message as output_dir_check {
            input:
                message = "ERROR: The output_cloud_directory directory does not start with 'gs://'."
        }
    }

    # Check that the DADA2 runtime (if provided) is an allowed size
    if (defined(dada2_runtime_size) && !(dada2_runtime_size == "small" || dada2_runtime_size == "medium" || dada2_runtime_size == "large")) {
        call ErrorWithMessage.error_with_message as runtime_check {
            input: message = "Invalid DADA2 runtime size provided: " + dada2_runtime_size + ". Must be 'small', 'medium', or 'large'."
        }
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

    # Generate final amplicon info
    call ProcessInputsWf.generate_amplicon_info {
        input:
            pools = pools,
            docker_image = docker_image,
            amplicon_info_files = amplicon_info_files_final
    }

    # Step 1: Demultiplex amplicons by target region
    # This separates reads by amplicon target and performs initial quality filtering
    call DemultiplexAmpliconsWf.demultiplex_amplicons {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            forward_fastqs = forward_fastqs,
            reverse_fastqs = reverse_fastqs,
            sequencer = sequencer,
            cutadapt_minlen = cutadapt_minlen,
            allowed_errors = allowed_errors,
            docker_image = docker_image
    }

    # Step 2: First denoising step using DADA2
    # This performs error correction, dereplication, and initial ASV inference
    call DenoiseAmplicons1Wf.denoise_amplicons_1 {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            demultiplexed_dir_tars = demultiplex_amplicons.demux_fastqs_ch,
            dada2_pool = dada2_pool,
            band_size = band_size,
            omega_a = omega_a,
            max_ee = max_ee,
            just_concatenate = just_concatenate,
            additional_memory = dada2_additional_memory,
            dada2_runtime_size = dada2_runtime_size,
            docker_image = docker_image
    }

    # Step 3: Second denoising step with masking and collapsing
    # This performs sequence masking, collapses similar ASVs, and creates final ASV table
    call DenoiseAmplicons2Wf.denoise_amplicons_2 {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            targeted_reference_files = select_first([targeted_reference_files, get_amplicon_and_targeted_ref_from_config.targeted_reference_files]),
            clusters = denoise_amplicons_1.dada2_clusters,
            just_concatenate = just_concatenate,
            refseq_fasta = refseq_fasta,
            masked_fasta = masked_fasta,
            mask_tandem_repeats = mask_tandem_repeats,
            mask_homopolymers = mask_homopolymers,
            genome = genome,
            docker_image = docker_image
    }

    # Step 4: Build final allele table
    # This creates the comprehensive allele frequency table combining all samples and amplicons
    call BuildAlleletable.build_alleletable {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            denoised_asvs = denoise_amplicons_1.dada2_clusters,
            processed_asvs = denoise_amplicons_2.results_ch,
            docker_image = docker_image
    }

    # Step 5: Generate quality control report
    # This creates comprehensive QC metrics and visualizations for the entire run
    call QualityControlWf.quality_control {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            sample_coverage_files = demultiplex_amplicons.sample_summary_ch,
            amplicon_coverage_files = demultiplex_amplicons.amplicon_summary_ch,
            alleledata = build_alleletable.alleledata,
            clusters = denoise_amplicons_1.dada2_clusters,
            docker_image = docker_image
    }

    # Step 6: Resistance marker analysis
    # This identifies and analyzes known resistance markers in the final ASV data
    call ResistanceMarkerModuleWf.resistance_marker_module {
        input:
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            allele_data = build_alleletable.alleledata,
            alignment_data = denoise_amplicons_2.aligned_asv_table,
            reference = denoise_amplicons_2.reference_ch,
            principal_resmarkers = principal_resmarkers,
            resmarkers_info_tsv = resmarkers_info_tsv,
            docker_image = docker_image
    }

    call MoveOutputs.move_outputs {
        input:
            output_cloud_directory = output_cloud_directory,
            amplicon_info_ch = generate_amplicon_info.amplicon_info_ch,
            final_allele_table = build_alleletable.alleledata,
            sample_coverage = quality_control.sample_coverage,
            amplicon_coverage = quality_control.amplicon_coverage,
            dada2_clusters = denoise_amplicons_1.dada2_clusters,
            resmarkers_output = resistance_marker_module.resmarkers_output,
            resmarkers_by_locus = resistance_marker_module.resmarkers_by_locus,
            microhaps = resistance_marker_module.microhaps,
            new_mutations = resistance_marker_module.new_mutations,
            reference_fasta = denoise_amplicons_2.reference_ch,
            resmarkers_file = resistance_marker_module.resmarkers_file,
    }

    output {
        String allele_data = move_outputs.allele_data
        String sample_coverage = move_outputs.sample_coverage
        String amplicon_coverage = move_outputs.amplicon_coverage
        String dada2_clusters = move_outputs.dada2_clusters
        String resmarker_table = move_outputs.resmarker_table
        String resmarker_table_by_locus = move_outputs.resmarker_table_by_locus
        String resmarker_microhaplotype_table = move_outputs.resmarker_microhaplotype_table
        String all_mutations_table = move_outputs.all_mutations_table
        String amplicon_info = move_outputs.amplicon_info
        String reference = move_outputs.reference
        String resmarker_info = move_outputs.resmarker_info
    }
}