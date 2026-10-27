version 1.0

# Identify the Terra workspace and submission that this Cromwell job is part of,
# from inside the job itself.
#
# Copied from broadinstitute/long-read-pipelines; descended from the task the Viral team
# maintains in broadinstitute/viral-pipelines (pipes/WDL/tasks/tasks_terra.wdl).

task get_terra_env_info {

    meta {
        description: "Self-identify, from inside a running Cromwell job, BOTH (a) the full Terra workspace metadata and (b) the submission and per-sample data table this workflow was launched from. Workspace resolution order: explicit namespace+workspace inputs; else the workspace bucket UUID scraped from the task's own gcs_delocalization.sh; else the WORKSPACE_NAMESPACE/WORKSPACE_NAME env vars (interactive runtimes); else the VM's Google project matched against the workspace list. Submission info (sample_table, submission id, root row id) is filled whenever the job was launched from a submission with a root entity. Authenticates with the task's attached service-account token from the GCE metadata server; pure python3/urllib, so no gcloud/jq/curl/fiss and it runs in any python image. Emits empty strings / is_running_on_terra=false when not on Terra."
        volatile: true
    }

    parameter_meta {
        namespace:    "Optional Terra billing project / namespace override. Auto-detected when omitted."
        workspace:    "Optional workspace name override. Auto-detected when omitted."
    }

    input {
        String? namespace
        String? workspace
    }

    command <<<
        set -euo pipefail

        export OVERRIDE_NAMESPACE="~{default='' namespace}"
        export OVERRIDE_WORKSPACE="~{default='' workspace}"

        python3 <<'PYEOF'
        import json, os, re, sys, glob, urllib.parse, urllib.request

        UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        FIRECLOUD = "https://api.firecloud.org"

        def write(path, val):
            with open(path, "w") as fh:
                fh.write("" if val is None else str(val))

        # --- default / not-on-Terra outputs ---
        scalars = ["workspace_namespace", "workspace_name", "workspace_id",
                   "bucket_name", "bucket_uri", "google_project", "created_by",
                   "created_date", "last_modified", "access_level", "description",
                   "sample_table", "top_level_submission_id", "input_row_id"]
        for s in scalars:
            write(s + ".txt", "")
        write("is_locked.txt", "false")
        write("is_running_on_terra.txt", "false")
        write("auth_domains.txt", "")
        with open("workspace_metadata.json", "w") as fh:
            fh.write("{}")
        with open("workspace_attributes.json", "w") as fh:
            fh.write("{}")

        def metadata(path):
            req = urllib.request.Request(
                "http://metadata.google.internal/computeMetadata/v1/" + path,
                headers={"Metadata-Flavor": "Google"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                return resp.read().decode()

        def metadata_token():
            return json.loads(metadata(
                "instance/service-accounts/default/token"))["access_token"]

        def api_get(url, token):
            req = urllib.request.Request(
                url, headers={"Authorization": "Bearer " + token,
                              "Accept": "application/json"})
            with urllib.request.urlopen(url=req, timeout=60) as resp:
                return json.load(resp)

        def q(s):
            return urllib.parse.quote(s, safe="")

        # --- must be on GCP/Terra to reach any Terra API ---
        try:
            token = metadata_token()
        except Exception as e:
            sys.stderr.write("Not on GCP/Terra (no metadata server: %s); "
                             "emitting empty detection.\n" % e)
            sys.exit(0)

        override_ns = os.environ.get("OVERRIDE_NAMESPACE", "") or None
        override_ws = os.environ.get("OVERRIDE_WORKSPACE", "") or None

        # --- scrape this task's gcs_delocalization.sh for bucket UUID + submission id ---
        ws_uuid = None
        submission_id = None
        candidates = []
        for root in ("/cromwell_root", "/mnt/disks/cromwell_root"):
            candidates += glob.glob(root + "/**/gcs_delocalization.sh", recursive=True)
            candidates += glob.glob(root + "/gcs_delocalization.sh")
        if candidates:
            script = open(sorted(candidates, key=len)[0]).read()
            ws_uuids = set(re.findall(r"gs://fc-(?:secure-)?(" + UUID + r")\b", script))
            sub_ids = set(re.findall(
                r"gs://fc-(?:secure-)?" + UUID +
                r"/submissions/(?:intermediates/|final-outputs/)?(" + UUID + r")\b",
                script))
            if len(ws_uuids) == 1:
                ws_uuid = ws_uuids.pop()
            if len(sub_ids) == 1:
                submission_id = sub_ids.pop()

        # --- resolve the full workspace payload ---
        full = None
        if override_ns and override_ws:
            full = api_get(FIRECLOUD + "/api/workspaces/" + q(override_ns) +
                           "/" + q(override_ws), token)
        elif ws_uuid:
            # bucket UUID is 1:1 with the workspace; returns the full payload
            full = api_get(FIRECLOUD + "/api/workspaces/id/" + ws_uuid, token)
        else:
            ns = os.environ.get("WORKSPACE_NAMESPACE", "")
            name = os.environ.get("WORKSPACE_NAME", "")
            if ns and name:
                full = api_get(FIRECLOUD + "/api/workspaces/" + q(ns) + "/" + q(name), token)
            else:
                project = os.environ.get("GOOGLE_PROJECT", "")
                if not project:
                    try:
                        project = metadata("project/project-id").strip()
                    except Exception:
                        project = ""
                if project:
                    lst = api_get(
                        FIRECLOUD + "/api/workspaces?fields="
                        "workspace.namespace%2Cworkspace.name%2Cworkspace.googleProject",
                        token)
                    matches = sorted({
                        (w["workspace"]["namespace"], w["workspace"]["name"])
                        for w in lst
                        if w.get("workspace", {}).get("googleProject") == project})
                    if len(matches) == 1:
                        ns, name = matches[0]
                        full = api_get(FIRECLOUD + "/api/workspaces/" + q(ns) + "/" + q(name), token)
                    else:
                        sys.stderr.write(
                            "ERROR: could not uniquely resolve workspace for project "
                            "'%s' (%d match(es)); pass namespace+workspace.\n"
                            % (project, len(matches)))
                        sys.exit(1)

        if full is None:
            sys.stderr.write("ERROR: on Terra but could not resolve the workspace "
                             "(no override, no delocalization bucket, no env vars, "
                             "no project match).\n")
            sys.exit(1)

        ws = full.get("workspace", {}) or {}
        attrs = ws.get("attributes", {}) or {}
        namespace = ws.get("namespace", "")
        name = ws.get("name", "")

        # --- write full metadata + scalars (GetWorkspaceMetadata parity) ---
        with open("workspace_metadata.json", "w") as fh:
            json.dump(full, fh, indent=2, sort_keys=True)
        with open("workspace_attributes.json", "w") as fh:
            json.dump(attrs, fh, indent=2, sort_keys=True)

        write("workspace_namespace.txt", namespace)
        write("workspace_name.txt", name)
        write("workspace_id.txt", ws.get("workspaceId", ""))
        write("bucket_name.txt", ws.get("bucketName", ""))
        write("bucket_uri.txt", ("gs://" + ws["bucketName"]) if ws.get("bucketName") else "")
        write("google_project.txt", ws.get("googleProject", ""))
        write("created_by.txt", ws.get("createdBy", ""))
        write("created_date.txt", ws.get("createdDate", ""))
        write("last_modified.txt", ws.get("lastModified", ""))
        write("is_locked.txt", "true" if ws.get("isLocked") else "false")
        write("access_level.txt", full.get("accessLevel", ""))
        write("description.txt", attrs.get("description", ""))
        ad = [g.get("membersGroupName", "")
              for g in (ws.get("authorizationDomain", []) or [])]
        write("auth_domains.txt", "\n".join([x for x in ad if x]))
        write("is_running_on_terra.txt", "true")

        # --- submission + per-sample table (get_terra_submission_info parity) ---
        if submission_id and namespace and name:
            write("top_level_submission_id.txt", submission_id)
            sub = api_get(FIRECLOUD + "/api/workspaces/" + q(namespace) + "/" +
                          q(name) + "/submissions/" + submission_id, token)
            # Prefer the per-workflow entities over submissionEntity. When several rows
            # are launched at once Terra wraps them in a transient <type>_set entity
            # named after the method config, then deletes it, so submissionEntity points
            # at something that no longer exists. The per-workflow entity is the real
            # row, and all workflows in a submission share one entity type, so the first
            # is enough to find the member table.
            entities = [w["workflowEntity"] for w in (sub.get("workflows") or [])
                        if w.get("workflowEntity")]
            if entities:
                root_type = entities[0].get("entityType", "")
                root_name = entities[0].get("entityName", "")
                row_ids = ",".join(e.get("entityName", "") for e in entities)
            else:
                se = sub.get("submissionEntity") or {}
                root_type = se.get("entityType", "")
                root_name = se.get("entityName", "")
                row_ids = root_name
            write("input_row_id.txt", row_ids)
            sample_table = ""
            if root_type.endswith("_set") and root_name:
                try:
                    ent = api_get(FIRECLOUD + "/api/workspaces/" + q(namespace) + "/" +
                                  q(name) + "/entities/" + q(root_type) + "/" + q(root_name),
                                  token)
                except Exception as e:
                    # Table detection is best-effort. Leave it undetected and exit clean
                    # rather than killing the run on a traceback; every other output has
                    # already been written, and the caller fails with its own message if
                    # it actually needed sample_table.
                    sys.stderr.write("WARNING: could not read root entity %s/%s (%s); "
                                     "sample_table left undetected.\n"
                                     % (root_type, root_name, e))
                    write("sample_table.txt", "")
                    sys.exit(0)
                ea = ent.get("attributes", {}) or {}
                ref_member = {k: v["items"][0]["entityType"]
                              for k, v in ea.items()
                              if isinstance(v, dict)
                              and v.get("itemsType") == "EntityReference"
                              and v.get("items")}
                canonical = root_type[:-4] + "s"
                if canonical in ref_member:
                    sample_table = ref_member[canonical]
                else:
                    distinct = set(ref_member.values())
                    if len(distinct) == 1:
                        sample_table = distinct.pop()
                    else:
                        sys.stderr.write("ERROR: could not uniquely resolve the "
                                         "member table of set %s (%s): %r\n"
                                         % (root_type, root_name, ref_member))
                        sys.exit(1)
            else:
                sample_table = root_type
            write("sample_table.txt", sample_table)
            sys.stderr.write("Detected submission=%s sample_table=%s\n"
                             % (submission_id, sample_table))

        sys.stderr.write("Detected workspace %s/%s (bucket gs://%s)\n"
                         % (namespace, name, ws.get("bucketName", "?")))
        PYEOF
    >>>

    output {
        Boolean       is_running_on_terra    = read_boolean("is_running_on_terra.txt")

        # Full workspace metadata (GetWorkspaceMetadata parity)
        File          metadata_json          = "workspace_metadata.json"
        File          attributes_json        = "workspace_attributes.json"
        String        workspace_namespace    = read_string("workspace_namespace.txt")
        String        workspace_name         = read_string("workspace_name.txt")
        String        workspace_id           = read_string("workspace_id.txt")
        String        bucket_name            = read_string("bucket_name.txt")
        String        bucket                 = read_string("bucket_uri.txt")
        String        google_project         = read_string("google_project.txt")
        String        created_by             = read_string("created_by.txt")
        String        created_date           = read_string("created_date.txt")
        String        last_modified          = read_string("last_modified.txt")
        Boolean       is_locked              = read_boolean("is_locked.txt")
        String        access_level           = read_string("access_level.txt")
        String        description            = read_string("description.txt")
        Array[String] authorization_domains  = read_lines("auth_domains.txt")

        # Submission + per-sample table (get_terra_submission_info parity)
        String        sample_table           = read_string("sample_table.txt")
        String        top_level_submission_id = read_string("top_level_submission_id.txt")
        String        input_row_id           = read_string("input_row_id.txt")
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-lrma/lr-backup-workspace:0.0.1"
        memory: "2 GiB"
        cpu: 1
        maxRetries: 2
    }
}
