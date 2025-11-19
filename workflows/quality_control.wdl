version 1.0

import "../modules/local/preprocess_coverage.wdl" as preprocess_coverage
import "../modules/local/postprocess_coverage.wdl" as postprocess_coverage


workflow quality_control {
    input {
        File amplicon_info_ch
        Array[File] sample_coverage_files
        Array[File] amplicon_coverage_files
        File? alleledata
        File? clusters
        String docker_image
    }

    # Initial Preprocessing
    call preprocess_coverage.preprocess_coverage {
        input:
            sample_coverages = sample_coverage_files,
            amplicon_coverages = amplicon_coverage_files,
            docker_image = docker_image
    }

    # If postprocessing coverage is provided, run the postprocessing workflow
    if (defined(alleledata) && defined(clusters)) {
        File defined_alleledata = select_first([alleledata])
        File defined_clusters = select_first([clusters])

        call postprocess_coverage.postprocess_coverage {
            input:
                alleledata = defined_alleledata,
                clusters = defined_clusters,
                sample_coverage = preprocess_coverage.sample_coverage,
                amplicon_coverage = preprocess_coverage.amplicon_coverage
        }
    }

    File final_sample_coverage = select_first([postprocess_coverage.postprocess_sample_coverage, preprocess_coverage.sample_coverage])
    File final_amplicon_coverage = select_first([postprocess_coverage.postprocess_amplicon_coverage, preprocess_coverage.amplicon_coverage])

    output {
        File sample_coverage = final_sample_coverage
        File amplicon_coverage = final_amplicon_coverage
    }
}