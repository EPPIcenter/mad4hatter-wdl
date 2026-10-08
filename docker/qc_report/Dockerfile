FROM rocker/tidyverse:4.4.2

# R packages needed by qc_report.qmd beyond what tidyverse already provides
RUN R -e "install.packages(c('ggbeeswarm', 'kableExtra', 'plotly'), repos = 'https://cloud.r-project.org')"

# Quarto CLI, used to render qc_report.qmd
ARG QUARTO_VERSION=1.6.39
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && apt-get install -y ./quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && rm quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Python + pyops-service-toolkit, used by write_metrics_to_sample_table.py to
# upsert QC status onto the Terra workspace sample table
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip git \
    && rm -rf /var/lib/apt/lists/*
ARG PYOPS_SERVICE_TOOLKIT_VERSION=12.19.0
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed \
        "git+https://github.com/broadinstitute/pyops-service-toolkit.git@v${PYOPS_SERVICE_TOOLKIT_VERSION}#egg=pyops-service-toolkit"

RUN mkdir -p /opt/mad4hatter/bin
COPY bin/qc_report.qmd /opt/mad4hatter/bin/qc_report.qmd
COPY bin/write_metrics_to_sample_table.py /opt/mad4hatter/bin/write_metrics_to_sample_table.py
