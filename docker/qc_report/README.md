# Building the QC Report Docker Image

This image bundles everything `Mad4HatterQcReport.wdl` needs: R + Quarto + the
plotting/report packages for `qc_report.qmd`, and Python +
`pyops-service-toolkit` for `write_metrics_to_sample_table.py`.

Terra/Cromwell workers run on `linux/amd64` GCP VMs. If you're building on an
Apple Silicon Mac (M1/M2/M3/M4), Docker defaults to building an `arm64` image,
which **will not run** on those workers — you must explicitly cross-build for
`linux/amd64`.

## Build

Run from the **repo root** (not this directory), since the Dockerfile copies
files from `bin/`:

```bash
docker buildx build \
  --platform linux/amd64 \
  -f docker/qc_report/Dockerfile \
  -t <your-registry>/mad4hatter-qc-report:<tag> \
  --load \
  .
```

- `--platform linux/amd64` forces the cross-build for GCP compatibility.
- `--load` pulls the built image into your local Docker so you can inspect/test it
  (omit this and use `--push` instead if you want to build and push in one step).

## Push

```bash
docker push <your-registry>/mad4hatter-qc-report:<tag>
```

If pushing to Google Artifact Registry/GCR instead of Docker Hub, authenticate
first with `gcloud auth configure-docker <region>-docker.pkg.dev` (or the
legacy `gcr.io` host), then tag/push as above using that registry's path.

## Use in the workflow

Pass the pushed tag as the `docker_image` input when launching
`Mad4HatterQcReport.wdl` in Terra — it's used for both the `generate_qc_report`
and `write_metrics_to_workspace_table` tasks.
