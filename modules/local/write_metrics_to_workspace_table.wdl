version 1.0

task write_metrics_to_workspace_table {
    input {
        File reprep_repool_summary
        File manifest
        File sample_read_counts
        File polyclonal_information
        File neg_control_information
        String workspace_name
        String workspace_billing_project
        String entity_type = "sample"
        String docker_image
    }

    command <<<
        set -euo pipefail

        python3 /opt/mad4hatter/bin/write_metrics_to_sample_table.py \
            --summary ~{reprep_repool_summary} \
            --manifest ~{manifest} \
            --sample-read-counts ~{sample_read_counts} \
            --polyclonal-information ~{polyclonal_information} \
            --neg-control-information ~{neg_control_information} \
            --workspace-namespace ~{workspace_billing_project} \
            --workspace-name ~{workspace_name} \
            --entity-type ~{entity_type} \
            --batch-pass-output batch_pass.txt
    >>>

    output {
        String batch_pass = read_string("batch_pass.txt")
    }

    runtime {
        docker: docker_image
    }
}
