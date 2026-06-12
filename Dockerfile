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

# marp-cli + the marpit core. Community themes (marp-theme-am,
# marp-theme-academic, …) used to be installed here but they don't
# exist on npm anymore — they were renamed to scoped packages and
# the namespace flipped. Themes ship via the `theme:` front-matter
# pointing at a CSS file in the project tree instead.
RUN npm install -g \
        @marp-team/marp-cli \
        @marp-team/marpit

ENV CHROME_PATH=/usr/bin/chromium

# Bundled Marp themes for French academic / public-sector
# institutions : polytechnique, ip-paris, cnrs, dinum, paris-saclay.
# Each is a self-contained CSS file copied into /opt/marp/themes/.
# Users select via `theme: <name>` in the YAML front-matter ;
# marp-cli discovers them through the `--theme-set` CLI flag the
# weft-loom-server's compile dispatcher passes by default.
COPY themes/ /opt/marp/themes/
# Wrap the marp-cli binary so every invocation auto-discovers the
# bundled themes — users don't have to pass `--theme-set` per call.
# The real marp lives at /usr/local/lib/node_modules/@marp-team/marp-cli/marp-cli.js ;
# we rename the npm shim then shadow it with a 5-line wrapper.
RUN mv /usr/local/bin/marp /usr/local/bin/marp-real \
 && printf '#!/bin/sh\nexec /usr/local/bin/marp-real --theme-set /opt/marp/themes "$@"\n' > /usr/local/bin/marp \
 && chmod +x /usr/local/bin/marp

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
