version 1.0

# Print given message to stderr and return an error
task get_amplicon_and_targeted_ref_from_config {
    input {
        Array[String] pools
        String docker_image
        String pool_options_json = "/opt/mad4hatter/conf/terra_panel.json" # located on docker
    }

    command <<<
        set -euo pipefail
        set -x

        python3 <<CODE

        import json
        import logging
        import shutil
        import os

        logging.basicConfig(level=logging.INFO)

        logging.info("Loading pool configuration from JSON")
        with open("~{pool_options_json}") as f:
            pool_config = json.load(f)

        amplicon_info_paths = []
        targeted_reference_paths = []
        missing_pools = []

        logging.info("Processing requested pools: ~{sep=',' pools}")
        for pool in "~{sep=',' pools}".split(","):
            if pool in pool_config['pool_options']:
                amplicon_info_paths.append(pool_config['pool_options'][pool]["amplicon_info_path"])
                targeted_reference_paths.append(pool_config['pool_options'][pool]["targeted_reference_path"])
            else:
                missing_pools.append(pool)
        if missing_pools:
            raise ValueError(f"The following pools are not available in the config: {', '.join(missing_pools)}")

        logging.info("Copying amplicon info and targeted reference files to output directories")
        os.makedirs("amplicon_info_files", exist_ok=True)
        os.makedirs("targeted_reference_files", exist_ok=True)
        for amplicon_file in amplicon_info_paths:
            shutil.copy2(amplicon_file, "amplicon_info_files/")
        for reference_file in targeted_reference_paths:
            shutil.copy2(reference_file, "targeted_reference_files/")
        CODE
    >>>

    output {
        Array[File] amplicon_info_files = glob("amplicon_info_files/*")
        Array[File] targeted_reference_files = glob("targeted_reference_files/*")
    }

    runtime {
        docker: docker_image
    }
}