version 1.0

import "modules/local/generate_qc_report.wdl" as GenerateQcReport
import "modules/local/write_metrics_to_workspace_table.wdl" as WriteMetricsToWorkspaceTable

workflow Mad4HatterQcReport {
    input {
        # Mad4hatter pipeline outputs for a single run. Named to match
        # Mad4Hatter.wdl's own output names.
        File sample_coverage
        File amplicon_coverage
        File allele_data
        File allele_table_collapsed
        File amplicon_info
        File resmarker_table
        File resmarker_microhaplotype_table

        # Sample manifest TSV (sample_name, SampleType, Batch, Column, Row, Parasitemia).
        File manifest

        # ADVANCED SETTINGS (defaults match QC_report.ipynb)
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

        # Terra workspace identifiers used to write QC status back onto the
        # workspace's sample data table.
        String workspace_name
        String workspace_billing_project

        String docker_image = "us-central1-docker.pkg.dev/operations-portal-427515/qc-report/mad4hatter-qc-report:latest"
    }

    call GenerateQcReport.generate_qc_report {
        input:
            sample_coverage_postprocessed = sample_coverage,
            amplicon_coverage_postprocessed = amplicon_coverage,
            allele_data = allele_data,
            allele_data_collapsed = allele_table_collapsed,
            amplicon_info = amplicon_info,
            resmarker_table = resmarker_table,
            resmarker_microhaplotype_table = resmarker_microhaplotype_table,
            manifest = manifest,
            standardise_sample_name = standardise_sample_name,
            read_threshold = read_threshold,
            read_filter = read_filter,
            af_filter = af_filter,
            negative_control_read_threshold = negative_control_read_threshold,
            reprep_threshold = reprep_threshold,
            repool_threshold = repool_threshold,
            allele_col = allele_col,
            long_target_threshold = long_target_threshold,
            filter_wsaf_final_allele_table = filter_wsaf_final_allele_table,
            reaction_as_pool = reaction_as_pool,
            docker_image = docker_image
    }

    call WriteMetricsToWorkspaceTable.write_metrics_to_workspace_table {
        input:
            reprep_repool_summary = generate_qc_report.reprep_repool_summary,
            manifest = manifest,
            sample_read_counts = generate_qc_report.sample_read_counts,
            polyclonal_information = generate_qc_report.polyclonal_information,
            neg_control_information = generate_qc_report.neg_control_information,
            workspace_name = workspace_name,
            workspace_billing_project = workspace_billing_project,
            docker_image = docker_image
    }

    output {
        File qc_report_html = generate_qc_report.qc_report_html
        File reprep_repool_summary = generate_qc_report.reprep_repool_summary
        File samples_to_repool = generate_qc_report.samples_to_repool
        File samples_to_reprep = generate_qc_report.samples_to_reprep
        File polyclonal_information = generate_qc_report.polyclonal_information
        File neg_control_information = generate_qc_report.neg_control_information
        File missing_samples_report = generate_qc_report.missing_samples_report
        File missing_targets_report = generate_qc_report.missing_targets_report
        File filtered_allele_data = generate_qc_report.filtered_allele_data
        File filtered_collapsed_allele_data = generate_qc_report.filtered_collapsed_allele_data
        File filtered_resmarker_table = generate_qc_report.filtered_resmarker_table
        File filtered_resmarker_microhaplotype_table = generate_qc_report.filtered_resmarker_microhaplotype_table
        File sample_read_counts = generate_qc_report.sample_read_counts
        String batch_pass = write_metrics_to_workspace_table.batch_pass
    }
}
