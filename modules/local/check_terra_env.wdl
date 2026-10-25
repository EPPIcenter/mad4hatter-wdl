version 1.0

# Inspect the backend to determine whether this task is running on Terra and/or GCP, and
# report back the Terra workspace / submission metadata for the run that invoked it.
#
# Copied from broadinstitute/long-read-pipelines (wdl/tasks/Utility/Utils.wdl), which in turn
# borrowed it from broadinstitute/viral-pipelines (pipes/WDL/tasks/tasks_terra.wdl).

task check_terra_env {
  input {}
  meta {
    description: "task for inspection of backend to determine whether the task is running on Terra and/or GCP"
    volatile: true
    provenance: "https://github.com/broadinstitute/viral-pipelines/blob/master/pipes/WDL/tasks/tasks_terra.wdl#L34"
    more_info: "Graciously borrowed from the Viral team's pipelines.  They spent a lot of time getting this right (they = Chris AKA @tomkinsc)" 
    author: "Chris Tomkins-Tinch"
  }
  command <<<
    # set -x # echo commands upon execution [commented out to avoid leaking the gcloud auth token]
    set -e # exit on pipe fail

    # create gcloud-related output file
    touch gcloud_config_info.log
    touch google_project_id.txt

    # create Terra-related output files
    touch user_email.txt
    touch workspace_id.txt
    touch workspace_name.txt
    touch workspace_namespace.txt
    touch workspace_bucket_path.txt
    touch input_table_name.txt
    touch input_row_id.txt
    touch method_version.txt
    touch method_source.txt
    touch method_path.txt
    touch top_level_submission_id.txt

    #touch gcp_created_by_attributes.txt
    touch gcp_instance_metadata.json

    # disable the version update alert messages gcloud sometimes emits when executing any command
    gcloud config set component_manager/disable_update_check true

    # write system environment variables to output file
    env | tee -a env_info.log

    echo "false" > RUNNING_ON_GCP_PAPIv2
    echo "false" > RUNNING_ON_GCP_BATCH

    # check if running on GCP
    if curl -s metadata.google.internal -i | grep -E 'Metadata-Flavor:\s+Google'; then 
      echo "Cloud platform appears to be GCP"; 
      echo "true" > RUNNING_ON_GCP

      GCLOUD_OAUTH_BEARER_TOKEN="$(gcloud auth print-access-token)"

      #curl -s -H "Metadata-Flavor: Google" \
      #  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/created-by" | tee gcp_created_by_attributes.txt

      curl -s -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/?recursive=true" | tee gcp_instance_metadata.json

      # if BATCH_JOB_UID has a value the job is running on GCP Batch
      # NOTE: PAPIv2 is deprecated and will be removed in the future
      if [[ -n "$BATCH_JOB_UID" ]] || $(jq -rc '.attributes | has("cloudbatch-job-uid")' gcp_instance_metadata.json); then
        echo "Job appears to be running on GCP Batch"
        echo "true"  > RUNNING_ON_GCP_BATCH
      else
        echo "Job appears to be running on GCP via PAPIv2"
        echo "true"  > RUNNING_ON_GCP_PAPIv2
      fi

      # Additional introspection can be performed on GCP by querying the internal metadata server
      #   for details see:
      #     https://cloud.google.com/compute/docs/metadata/predefined-metadata-keys

      # write gcloud env info to output files
      gcloud info | tee -a gcloud_config_info.log
    else 
      echo "NOT running on GCP";
      echo "false" > RUNNING_ON_GCP
    fi

    GOOGLE_PROJECT_ID="$(gcloud config list --format='value(core.project)')"
    echo "$GOOGLE_PROJECT_ID" > google_project_id.txt

    # check whether gcloud project has a "terra-" prefix
    # to determine if running on Terra
    if case ${GOOGLE_PROJECT_ID} in terra-*) ;; *) false;; esac; then
      # (shell-portable regex conditional)
      echo "Job appears to be running on Terra (GCP project ID: ${GOOGLE_PROJECT_ID})"
      echo "true" > RUNNING_ON_TERRA

      # get user e-mail for Terra account via firecloud API
      curl -s -X 'GET' \
        'https://api.firecloud.org/me?userDetailsOnly=true' \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $GCLOUD_OAUTH_BEARER_TOKEN" > user_info.json

        USER_EMAIL="$(jq -cr '.userEmail' user_info.json | tee user_email.txt)"
    else
      echo "NOT running on Terra"
      echo "false" > RUNNING_ON_TERRA
    fi

    if grep --quiet "true" RUNNING_ON_GCP && grep --quiet "true" RUNNING_ON_TERRA; then
      echo "Running on Terra+GCP"

      # === Determine Terra workspace ID and submission ID for the workspace responsible for this job

      # locate the Terra (de)localiztion scripts by running find on one of several known potential locations
      # the location may/does differ when running on GCP via PAPIv2 or via Google batch
      known_possible_terra_script_locations=(
                                              "/cromwell_root"
                                              "/mnt/disks/cromwell_root"
                                            )
      terra_localization_script_dirpath="$(dirname $(realpath $(find "${known_possible_terra_script_locations[@]}" -maxdepth 3 -iname gcs_delocalization.sh -print -quit)))"


      # Scrape various workflow / workspace info from the localization and delocalization scripts.
      #   from: https://github.com/broadinstitute/gatk/blob/ah_var_store/scripts/variantstore/wdl/GvsUtils.wdl#L35-L40
      WORKSPACE_ID="$(sed -n -E 's!.*gs://fc-(secure-)?([^\/]+).*!\2!p' ${terra_localization_script_dirpath}/gcs_delocalization.sh | sort -u | tee workspace_id.txt)"
      echo "WORKSPACE_ID:            ${WORKSPACE_ID}"

      # check that workspace ID is a valid UUID
      if ! [[ "$WORKSPACE_ID" =~ ^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$ ]]; then
        echo "ERROR: WORKSPACE_ID identified by parsing ${terra_localization_script_dirpath}/gcs_delocalization.sh is not a valid UUID"
        exit 1
      fi

      # bucket path prefix
      #BUCKET_PREFIX="$(sed -n -E 's!.*(gs://(fc-(secure-)?[^\/]+)).*!\1!p' /cromwell_root/gcs_delocalization.sh | sort -u | tee bucket_prefix.txt)"
      #echo "BUCKET_PREFIX: ${BUCKET_PREFIX}"

      # top-level submission ID
      TOP_LEVEL_SUBMISSION_ID="$(sed -n -E 's!.*gs://fc-(secure-)?([^\/]+)/submissions/([^\/]+).*!\3!p' ${terra_localization_script_dirpath}/gcs_delocalization.sh | sort -u | tee top_level_submission_id.txt)"
      echo "TOP_LEVEL_SUBMISSION_ID: ${TOP_LEVEL_SUBMISSION_ID}"

      # workflow job ID within submission
      #WORKFLOW_ID="$(sed -n -E 's!.*gs://fc-(secure-)?([^\/]+)/submissions/([^\/]+)/([^\/]+)/([^\/]+).*!\5!p' /cromwell_root/gcs_delocalization.sh | sort -u)"
      
      # other way to obtain Terra project ID, via scraping rather than from gcloud call used above
      #GOOGLE_PROJECT_ID="$(sed -n -E 's!.*(terra-[0-9a-f]+).*# project to use if requester pays$!\1!p' /cromwell_root/gcs_localization.sh | sort -u)"
      # =======================================

      # === request workspace name AND namespace from API, based on bucket path / ID ===
      curl -s -X 'GET' \
        "https://api.firecloud.org/api/workspaces/id/${WORKSPACE_ID}?fields=workspace.name%2Cworkspace.namespace%2Cworkspace.googleProject" \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $GCLOUD_OAUTH_BEARER_TOKEN" > workspace_info.json


      WORKSPACE_NAME="$(jq -cr '.workspace.name | select (.!=null)' workspace_info.json | tee workspace_name.txt)"
      WORKSPACE_NAME_URL_ENCODED="$(jq -rn --arg x "${WORKSPACE_NAME}" '$x|@uri')"
      WORKSPACE_NAMESPACE="$(jq -cr '.workspace.namespace | select (.!=null)' workspace_info.json | tee workspace_namespace.txt)"
      WORKSPACE_BUCKET="$(echo "gs://fc-${WORKSPACE_ID}" | tee workspace_bucket_path.txt)"

      echo "WORKSPACE_NAME:      ${WORKSPACE_NAME}"
      echo "WORKSPACE_NAMESPACE: ${WORKSPACE_NAMESPACE}"
      echo "WORKSPACE_BUCKET:    ${WORKSPACE_BUCKET}"

          # --- less direct way of obtaining workspace info by matching Terra project ID --
          #     preserved here for potential utility in obtaining workspace info for other projects/workspaces
          # get list of workspaces, limiting the output to only the fields we need
          #curl -s -X 'GET' \
          #'https://api.firecloud.org/api/workspaces?fields=workspace.name%2Cworkspace.namespace%2Cworkspace.bucketName%2Cworkspace.googleProject' \
          #-H 'accept: application/json' \
          #-H "Authorization: Bearer $GCLOUD_OAUTH_BEARER_TOKEN" > workspace_list.json

          # extract workspace name
          #WORKSPACE_NAME=$(jq -cr '.[] | select( .workspace.googleProject == "'${GOOGLE_PROJECT_ID}'" ).workspace | .name' workspace_list.json)
          
          # extract workspace namespace
          #WORKSPACE_NAMESPACE=$(jq -cr '.[] | select( .workspace.googleProject == "'${GOOGLE_PROJECT_ID}'" ).workspace | .namespace' workspace_list.json)
          #WORKSPACE_NAME_URL_ENCODED="$(jq -rn --arg x "${WORKSPACE_NAME}" '$x|@uri')"

          # extract workspace bucket
          #WORKSPACE_BUCKET=$(jq -cr '.[] | select( .workspace.googleProject == "'${GOOGLE_PROJECT_ID}'" ).workspace | .bucketName' workspace_list.json)
          # --- end less direct way of obtaining workspace info ---
      # =======================================


      # === obtain info on job submission inputs (table name, row ID) ===
      touch submission_metadata.json
      curl -s 'GET' \
      "https://api.firecloud.org/api/workspaces/${WORKSPACE_NAMESPACE}/${WORKSPACE_NAME_URL_ENCODED}/submissions/${TOP_LEVEL_SUBMISSION_ID}" \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $GCLOUD_OAUTH_BEARER_TOKEN" > submission_metadata.json

      INPUT_TABLE_NAME="$(jq -cr 'if .submissionEntity == null then "" elif (.workflows | length)==1 then .submissionEntity.entityType else [.workflows[].workflowEntity.entityType] | join(",") end' submission_metadata.json  | tee input_table_name.txt)"
      INPUT_ROW_ID="$(jq -cr 'if .submissionEntity == null then "" elif (.workflows | length)==1 then .submissionEntity.entityName else [.workflows[].workflowEntity.entityName] | join(",") end' submission_metadata.json | tee input_row_id.txt)"

      echo "INPUT_TABLE_NAME: $INPUT_TABLE_NAME"
      echo "INPUT_ROW_ID:     $INPUT_ROW_ID"
      # =======================================

      # === obtain info on workflow version (branch/tag) and source (dockstore, etc.) ===
      curl -s 'GET' \
        "https://rawls.dsde-prod.broadinstitute.org/api/workspaces/${WORKSPACE_NAMESPACE}/${WORKSPACE_NAME_URL_ENCODED}/submissions/${TOP_LEVEL_SUBMISSION_ID}/configuration" \
        -H 'accept: application/json' \
        -H "Authorization: Bearer $GCLOUD_OAUTH_BEARER_TOKEN" > workflow_version_info.json

      # .methodConfigVersion corresponds to snapshot of input/output config (or a method version stored in Broad methods repo?)
      #jq -cr .methodConfigVersion workflow_version_info.json
      METHOD_VERSION="$(jq -cr '.methodRepoMethod.methodVersion | select (.!=null)' workflow_version_info.json | tee method_version.txt)"
      METHOD_SOURCE="$(jq -cr '.methodRepoMethod.sourceRepo | select (.!=null)' workflow_version_info.json | tee method_source.txt)"
      METHOD_PATH="$(jq -cr '.methodRepoMethod.methodPath | select (.!=null)' workflow_version_info.json | tee method_path.txt)"

      echo "METHOD_VERSION: $METHOD_VERSION"
      echo "METHOD_SOURCE:  $METHOD_SOURCE"
      echo "METHOD_PATH:    $METHOD_PATH"
      # =======================================
    else 
      echo "Not running on Terra+GCP"
    fi

    # pretty-print environment details to stdout
    # if wraping is desired, add to 'column' command: --output-width 120 --table-wrap 0
    ###### disable stdout messages until fixed
    #echo "=============================================="
    #find . -maxdepth 1 -type f \( -iname 'RUNNING*' -or -iname '*.txt' \) -exec sh -c 'printf "$(basename $1 .txt)\t$(head -n1 $1)\n"' _ {} \; | sort -k1 -d -t $'\t' | column --separator $'\t' --table --table-right 1 --output-separator $'  '
    #echo "=============================================="

    echo -n'' "MEM_BYTES: "; { if [ -f /sys/fs/cgroup/memory.peak ]; then cat /sys/fs/cgroup/memory.peak; elif [ -f /sys/fs/cgroup/memory/memory.max_usage_in_bytes ]; then cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes; else echo "0"; fi } | tee MEM_BYTES
  >>>
  output {
    Boolean is_running_on_terra    = read_boolean("RUNNING_ON_TERRA")

    Boolean is_backed_by_gcp          = read_boolean("RUNNING_ON_GCP")
    Boolean is_running_via_gcp_batch  = read_boolean("RUNNING_ON_GCP_BATCH")
    Boolean is_running_via_gcp_papiv2 = read_boolean("RUNNING_ON_GCP_PAPIv2")

    String google_project_id       = read_string("google_project_id.txt")

    String user_email              = read_string("user_email.txt")

    String workspace_uuid            = read_string("workspace_id.txt")
    String workspace_name          = read_string("workspace_name.txt")
    String workspace_namespace     = read_string("workspace_namespace.txt")
    String workspace_bucket_path   = read_string("workspace_bucket_path.txt")

    String method_version          = read_string("method_version.txt")
    String method_source           = read_string("method_source.txt")
    String method_path             = read_string("method_path.txt")

    #String gcp_created_by_metadata = read_string("gcp_created_by_attributes.txt")
    File   gcp_instance_metadata   = "gcp_instance_metadata.json"

    String input_table_name        = read_string("input_table_name.txt")
    String input_row_id            = read_string("input_row_id.txt")

    String top_level_submission_id = read_string("top_level_submission_id.txt")

    File env_info                  = "env_info.log"
    File gcloud_config_info        = "gcloud_config_info.log"

    Int  max_ram_gb                = ceil(read_float("MEM_BYTES")/1000000000)
  }
  runtime {
    docker: "us.gcr.io/broad-dsp-lrma/lr-basic:0.1.3"
    memory: "1 GB"
    cpu: 1
    maxRetries: 1
  }
}

