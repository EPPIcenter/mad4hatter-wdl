version 1.0

task move_outputs {
    input {
        File final_allele_table
        File sample_coverage
        File amplicon_coverage
        File dada2_clusters
        File resmarkers_output
        File resmarkers_by_locus
        File microhaps
        File new_mutations
        File amplicon_info_ch
        File reference_fasta
        File resmarkers_file
        String output_directory
    }

    String bucket_name = sub(final_allele_table, ".*/(fc-[^/]+).*", "$1")

    command <<<
        set -e

        # Get "now" timestamp for writing outputs
        timestamp=$(date +"%Y-%m-%d_%H%M%S")

        # Function to copy a file and echo its destination path
        copy_file() {
            local file=$1
            local subdirectory=$2
            local filename=$(basename "$file")

            if [[ -n "$subdirectory" ]]; then
                destination="gs://~{bucket_name}/~{output_directory}/$timestamp/$subdirectory/$filename"
            else
                # Otherwise, copy directly under output_directory
                destination="gs://~{bucket_name}/~{output_directory}/$timestamp/$filename"
            fi

            echo "Copying $file to $destination"
            gcloud alpha storage cp "$file" "$destination"

            echo $destination > $filename.file_path
        }

        # Copy individual files
        copy_file "~{final_allele_table}" ""
        copy_file "~{sample_coverage}" ""
        copy_file "~{amplicon_coverage}" ""
        copy_file "~{dada2_clusters}" "raw_dada2_output"
        copy_file "~{resmarkers_output}" "resistance_marker_module"
        copy_file "~{resmarkers_by_locus}" "resistance_marker_module"
        copy_file "~{microhaps}" "resistance_marker_module"
        copy_file "~{new_mutations}" "resistance_marker_module"
        copy_file "~{amplicon_info_ch}" "panel_information"
        copy_file "~{reference_fasta}" "panel_information"
        copy_file "~{resmarkers_file}" "panel_information"
    >>>

    output {
        String allele_data = read_string("~{basename(final_allele_table)}.file_path")
        String sample_coverage = read_string("~{basename(sample_coverage)}.file_path")
        String amplicon_coverage = read_string("~{basename(amplicon_coverage)}.file_path")
        String dada2_clusters = read_string("~{basename(dada2_clusters)}.file_path")
        String resmarker_table = read_string("~{basename(resmarkers_output)}.file_path")
        String resmarker_table_by_locus = read_string("~{basename(resmarkers_by_locus)}.file_path")
        String resmarker_microhaplotype_table = read_string("~{basename(microhaps)}.file_path")
        String all_mutations_table = read_string("~{basename(new_mutations)}.file_path")
        String amplicon_info = read_string("~{basename(amplicon_info_ch)}.file_path")
        String reference = read_string("~{basename(reference_fasta)}.file_path")
        String resmarker_info = read_string("~{basename(resmarkers_file)}.file_path")
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:540.0.0"
    }
}