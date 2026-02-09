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

        pool_name_mapping = {
            '1A': 'D1.1',
            '1B': 'R1.1',
            '2' : 'R2.1',
            '5' : 'R1.2', 
            'D1' : 'D1.1',
            'R1' : 'R1.2',
            'R2' : 'R2.1',
            'M1' : 'M1.1',
            'M2' : 'M2.1',
        }

        updated_pool_names = []
        for pool in "~{sep=',' pools}".split(","):
            if pool in pool_config['pool_options']:
                amplicon_info_paths.append(pool_config['pool_options'][pool]["amplicon_info_path"])
                targeted_reference_paths.append(pool_config['pool_options'][pool]["targeted_reference_path"])
                if pool in pool_name_mapping: 
                    updated_pool_names.append(pool_name_mapping[pool])
                else: 
                    updated_pool_names.append(pool)
            else:
                missing_pools.append(pool)
        if missing_pools:
            missing = ', '.join(missing_pools)
            error_message = (
                f"ERROR: The following pools were requested but not found in the configuration: {missing}.\n"
                f"If you are using custom (bespoke) pools, you MUST provide the corresponding files manually:\n"
                f"  - `--amplicon_info` must be specified\n"
                f"  - and if running Mad4Hatter or Mad4hatterPostProcessing, EITHER `--refseq_fasta` OR `--genome` must also be provided."
            )
            raise ValueError(error_message)

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

        logging.info("Writing updated pool names to output file")
        with open("updated_pool_names.txt", "w") as f:
            for pool_name in updated_pool_names:
                f.write(pool_name + "\n")
        CODE
    >>>

    output {
        Array[File] amplicon_info_files = glob("amplicon_info_files/*")
        Array[File] targeted_reference_files = glob("targeted_reference_files/*")
        Array[String] updated_pool_names = read_lines("updated_pool_names.txt")
    }

    runtime {
        docker: docker_image
    }
}