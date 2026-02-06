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
        amplicon_fofn_path = "amplicon.fofn"
        targeted_reference_paths = []
        targeted_reference_fofn_path = "targeted_reference.fofn"
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
        with open("amplicon.fofn", "w") as amplicon_fofn:
            with open("targeted_reference.fofn", "w") as ref_fofn:
                for amplicon_file in amplicon_info_paths:
                    shutil.copy2(amplicon_file, "amplicon_info_files/")
                    amplicon_fofn.write(os.path.join("amplicon_info_files", os.path.basename(amplicon_file)) + "\n")
                for reference_file in targeted_reference_paths:
                    shutil.copy2(reference_file, "targeted_reference_files/")
                    ref_fofn.write(os.path.join("targeted_reference_files", os.path.basename(reference_file)) + "\n")
        with open(amplicon_fofn_path, "r") as f:
            for line in f:
                logging.info(f"Amplicon info file: {line.strip()}")
                os.path.exists(line.strip()) or logging.error(f"File does not exist: {line.strip()}")
        with open(targeted_reference_fofn_path, "r") as f:
            for line in f:
                logging.info(f"Targeted reference file: {line.strip()}")
                os.path.exists(line.strip()) or logging.error(f"File does not exist: {line.strip()}")
        logging.info("Files found in amplicon_info_files/:")
        for fname in os.listdir("amplicon_info_files/"):
            logging.info(os.path.join("amplicon_info_files/", fname))
        logging.info("Files found in targeted_reference_files/:")
        for fname in os.listdir("targeted_reference_files/"):
            logging.info(os.path.join("targeted_reference_files/", fname))
        CODE
    >>>

    output {
        Array[File] amplicon_info_files = read_lines("amplicon.fofn")
        Array[File] targeted_reference_files = read_lines("targeted_reference.fofn")
    }

    runtime {
        docker: docker_image
    }
}