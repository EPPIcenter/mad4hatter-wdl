version 1.0

task preprocess_coverage {
    input {
        Array[File] sample_coverages
        Array[File] amplicon_coverages
        String docker_image
    }

    command <<<
        set -euo pipefail

        add_sample_name_column() {
            fname=$(basename "$1" | sed -e 's/.SAMPLEsummary.txt//g' -e 's/.AMPLICONsummary.txt//g')
            awk -v fname="$fname" -v OFS="\t" '{print fname, $0}' "$1"
        }

        echo -e "SampleID\\tStage\\tReads" > preprocess_sample_coverage.txt
        echo -e "SampleID\\tLocus\\tReads" > preprocess_amplicon_coverage.txt

        echo "Processing sample files" >&2
        for file in ~{sep=" " sample_coverages}
        do
            add_sample_name_column $file >> preprocess_sample_coverage.txt
        done

        echo "Processing amplicon files" >&2
        for file in ~{sep=" " amplicon_coverages}
        do
            add_sample_name_column $file >> preprocess_amplicon_coverage.txt
        done

    >>>

    output {
        File sample_coverage = "preprocess_sample_coverage.txt"
        File amplicon_coverage = "preprocess_amplicon_coverage.txt"
    }

    runtime {
        docker: docker_image
    }
}