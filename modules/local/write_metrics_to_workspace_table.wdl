version 1.0

task write_metrics_to_workspace_table {
    input {
        File reprep_repool_summary
        String workspace_name
        String workspace_billing_project
        String entity_type = "sample"
        String docker_image
    }

    command <<<
        set -euo pipefail

        python3 /opt/mad4hatter/bin/write_metrics_to_sample_table.py \
            --summary ~{reprep_repool_summary} \
            --workspace-namespace ~{workspace_billing_project} \
            --workspace-name ~{workspace_name} \
            --entity-type ~{entity_type}
    >>>

    output {
        File upsert_log = stdout()
    }

    runtime {
        docker: docker_image
    }
}
