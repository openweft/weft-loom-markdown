# weft-loom-markdown — Markdown compile sandbox image for weft-loom.
#
# Covers BOTH common markdown-to-PDF paths in one image so weft-agent
# only needs to pull one OCI artifact for any markdown source :
#
#   - Marp slide decks   → marp-cli + Chromium    (YAML `marp: true`)
#   - Plain markdown     → pandoc + TeX Live      (everything else)
#
# Consumed by weft-agent when a weft-loom compile job has
# language="markdown". The loom-server detects the front-matter to
# pick which binary to invoke ; both live in this image so a project
# can mix the two without forcing a different image per file.
#
# Invocation contracts :
#
#   # Marp slide deck → PDF
#   docker run --rm \
#     -v <project>:/workspace:ro \
#     -v <scratch>:/workspace/.build:rw \
#     ghcr.io/openweft/weft-loom-markdown \
#     marp --pdf --allow-local-files \
#       -o /workspace/.build/output.pdf /workspace/main.md
#
#   # Pandoc → PDF
#   docker run --rm \
#     -v <project>:/workspace:ro \
#     -v <scratch>:/workspace/.build:rw \
#     ghcr.io/openweft/weft-loom-markdown \
#     pandoc -o /workspace/.build/output.pdf /workspace/main.md
#
# The image is published from .github/workflows/build.yml on every
# `v*` tag push to ghcr.io/openweft/weft-loom-markdown:<tag> + :latest.

FROM node:22-bookworm-slim

# Chromium for marp-cli PDF / PPTX export + TeX Live for pandoc PDF
# generation. texlive-xetex covers the pandoc default (XeLaTeX)
# without dragging in the full ~3 GB texlive-full. fonts-noto-cjk +
# noto-color-emoji let CJK + emoji slides render correctly.
RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-noto-cjk \
        libxss1 \
        libgbm1 \
        libasound2 \
        ca-certificates \
        pandoc \
        texlive-xetex \
        texlive-latex-recommended \
        texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

# marp-cli + a curated set of community themes the autocomplete in
# the weft-loom-server SPA suggests. Adding a theme here makes it
# usable inside marp-cli without any per-project install.
RUN npm install -g \
        @marp-team/marp-cli \
        @marp-team/marpit \
        marp-theme-am \
        marp-theme-academic

ENV CHROME_PATH=/usr/bin/chromium

# Apptainer runs as the host user — the Dockerfile USER directive
# is not honoured AND the bind mount maps host file ownership
# verbatim. A non-root USER in the image creates a permission trap
# (UID 1000 in the image can't read the project tree if the host
# UID differs). Stay root ; the sandbox boundary is the workspace
# μVM, not the container user.

WORKDIR /workspace
# Apptainer exec uses non-login shells — pin PATH so marp / pandoc
# are reachable.
ENV PATH=/usr/local/bin:/usr/bin:${PATH}

# No ENTRYPOINT — callers explicitly pass `marp …` or `pandoc …`
# depending on the source. Avoids the surprise where ENTRYPOINT=marp
# would make running pandoc awkward.
CMD ["bash"]
