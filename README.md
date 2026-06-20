<p align="center"><img src="https://raw.githubusercontent.com/openweft/brand/main/social/weft-loom-markdown.png" alt="weft-loom-markdown" width="720"></p>

# weft-loom-markdown

Markdown compile sandbox image for [weft-loom](https://github.com/openweft/weft-loom-server).

When a `weft-loom` compile job has `language="markdown"`, weft-agent
boots a microVM from this image, mounts the project working tree at
`/workspace`, and runs either :

- `marp` when the source carries `marp: true` in its YAML front-matter, or
- `pandoc` otherwise.

Both binaries live in this single image so a project can mix Marp
slides + plain markdown without forcing a different image per file.

## Invocation contracts

```sh
# Marp slide deck → PDF
docker run --rm \
  -v <project>:/workspace:ro \
  -v <scratch>:/workspace/.build:rw \
  ghcr.io/openweft/weft-loom-markdown \
  marp --pdf --allow-local-files \
    -o /workspace/.build/output.pdf /workspace/main.md

# Pandoc → PDF (XeLaTeX engine)
docker run --rm \
  -v <project>:/workspace:ro \
  -v <scratch>:/workspace/.build:rw \
  ghcr.io/openweft/weft-loom-markdown \
  pandoc -o /workspace/.build/output.pdf /workspace/main.md

# Marp → self-contained HTML
docker run --rm ... ghcr.io/openweft/weft-loom-markdown \
  marp --html -o /workspace/.build/out.html /workspace/main.md
```

The image's `CMD` is `bash` so callers always pass an explicit
binary + flags — no `ENTRYPOINT` ambiguity between marp and pandoc.

## Themes shipped

The image preinstalls a curated set of community Marp themes the
weft-loom SPA's autocomplete suggests :

- `default`, `gaia`, `uncover` — Marp built-ins
- `am_brown`, `am_dark`, `am_green`, `am_blue`, `am_pink`, `am_purple`, `am_red` — [marp-theme-am](https://github.com/ralexanderson/marp-theme-am)
- `academic` — [marp-theme-academic](https://github.com/kaisugi/marp-theme-academic)

Custom in-repo themes load via `marp --theme path/to/theme.css`.

## Pandoc capabilities

- XeLaTeX engine via `texlive-xetex`
- recommended LaTeX classes + fonts (`texlive-latex-recommended`, `texlive-fonts-recommended`)
- CJK + emoji rendering via fonts-noto-cjk + fonts-noto-color-emoji

For the heavier (~3 GB) `texlive-full` package use the dedicated
[weft-loom-texlive](https://github.com/openweft/weft-loom-texlive) image.

## Build & publish

```sh
git tag v0.1.0
git push origin v0.1.0
```

The CI workflow under `.github/workflows/build.yml` builds for
`linux/amd64` + `linux/arm64` and publishes to
`ghcr.io/openweft/weft-loom-markdown:<tag>` + `:latest`.

## License

BSD 3-Clause.
