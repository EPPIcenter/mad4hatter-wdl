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

        logging.basicConfig(
            format="%(levelname)s: %(asctime)s : %(message)s", level=logging.INFO
        )

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

        # Copy files with index-based naming to preserve order
        # Format: {index:03d}_{original_basename}
        for idx, amplicon_file in enumerate(amplicon_info_paths):
            original_basename = os.path.basename(amplicon_file)
            output_name = f"{idx:03d}_{original_basename}"
            output_path = os.path.join("amplicon_info_files", output_name)
            shutil.copy2(amplicon_file, output_path)
            logging.info(f"Copied amplicon file to: {output_path}")

        for idx, reference_file in enumerate(targeted_reference_paths):
            original_basename = os.path.basename(reference_file)
            output_name = f"{idx:03d}_{original_basename}"
            output_path = os.path.join("targeted_reference_files", output_name)
            shutil.copy2(reference_file, output_path)
            logging.info(f"Copied reference file to: {output_path}")
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