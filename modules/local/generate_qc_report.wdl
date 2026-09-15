version 1.0

task generate_qc_report {
    input {
        File zipped_outputs
        File manifest
        Boolean standardise_sample_name = true
        Int read_threshold = 100
        Int read_filter = 0
        Float af_filter = 0.01
        Int negative_control_read_threshold = 50
        Float reprep_threshold = 0.5
        Float repool_threshold = 0.75
        String allele_col = "pseudocigar_masked"
        Int long_target_threshold = 275
        Boolean filter_wsaf_final_allele_table = true
        Boolean reaction_as_pool = false
        String docker_image
    }

    command <<<
        set -euo pipefail

        cp /opt/mad4hatter/bin/qc_report.qmd .

        mkdir -p results
        unzip -q ~{zipped_outputs} -d results

        # The zip may contain the run's files directly or nested under a single
        # top-level folder (e.g. produced by `zip -r archive.zip run_folder/`).
        results_dir=$(dirname "$(find results -name 'sample_coverage_postprocessed.txt' | head -n1)")

        quarto render qc_report.qmd \
            --output qc_report.html \
            -P results_dir:"${results_dir}" \
            -P manifest_path:"~{manifest}" \
            -P output_dir:QC_report \
            -P standardise_sample_name:~{standardise_sample_name} \
            -P read_threshold:~{read_threshold} \
            -P read_filter:~{read_filter} \
            -P af_filter:~{af_filter} \
            -P negative_control_read_threshold:~{negative_control_read_threshold} \
            -P reprep_threshold:~{reprep_threshold} \
            -P repool_threshold:~{repool_threshold} \
            -P allele_col:~{allele_col} \
            -P long_target_threshold:~{long_target_threshold} \
            -P filter_wsaf_final_allele_table:~{filter_wsaf_final_allele_table} \
            -P reaction_as_pool:~{reaction_as_pool}
    >>>

    output {
        File qc_report_html = "qc_report.html"
        File reprep_repool_summary = "QC_report/reprep_repool_summary.csv"
        File samples_to_repool = "QC_report/samples_to_repool.csv"
        File samples_to_reprep = "QC_report/samples_to_reprep.csv"
        File polyclonal_information = "QC_report/positive_control_polyclonal_info.csv"
        File neg_control_information = "QC_report/negative_control_amplified_targets.csv"
        File missing_samples_report = "QC_report/missing_samples_report.csv"
        File missing_targets_report = "QC_report/missing_targets_report.csv"
        File filtered_allele_data = "QC_report/allele_data_filtered.txt"
        File filtered_collapsed_allele_data = "QC_report/allele_data_collapsed_filtered.txt"
        File filtered_resmarker_table = "QC_report/resmarker_table_filtered.txt"
        File filtered_resmarker_microhaplotype_table = "QC_report/resmarker_microhaplotype_table_filtered.txt"
    }

    runtime {
        docker: docker_image
        cpu: 2
        memory: "8 GB"
    }
}
