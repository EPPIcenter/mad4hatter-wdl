version 1.0

task postprocess_coverage {
    input {
        File alleledata
        File clusters
        File sample_coverage
        File amplicon_coverage
        String docker_image
    }

    command <<<
        set -euo pipefail

        Rscript /opt/mad4hatter/bin/asv_coverage.R \
            --alleledata ~{alleledata} \
            --clusters ~{clusters} \
            --sample-coverage ~{sample_coverage} \
            --amplicon-coverage ~{amplicon_coverage}
    >>>


    output {
        File postprocess_sample_coverage = "sample_coverage_postprocessed.txt"
        File postprocess_amplicon_coverage = "amplicon_coverage_postprocessed.txt"
    }

    runtime {
        docker: docker_image
    }
}