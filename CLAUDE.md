# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository creates digital field forms and QGIS projects for fish passage assessment, habitat assessment, and stream crossing climate change/maintenance risk assessment in British Columbia. The forms integrate with Mergin Maps for mobile field data collection on iOS and Android devices.

## Key Components

### Digital Field Forms (R Scripts)
R scripts in `scripts/` build geopackage-based field forms from provincial submission templates:
- **PSCIS forms**: `pscis_build_form.R` - Fish Passage stream crossing assessment
- **FISS Site forms**: `fiss_site_build_form.R` - Fish habitat site data
- **Fish Sample forms**: `fish_sample_build.R` - Fish sampling data
- **FHAP forms**: `fhap_build.R` - Fish habitat assessment
- **eDNA forms**: `edna_build.R` - Environmental DNA sampling
- **Monitoring forms**: `monitoring_build_form.R` - Restoration monitoring

Forms are written as `.gpkg` files to QGIS project directories (typically `~/Projects/gis/{project_name}/`).

### QGIS Project Creation (Shell Scripts)
Scripts in `scripts/qgis/` download BC government spatial data and create QGIS projects:

**Environment setup** (run from repo root):
```bash
conda env create -f environment.yml
conda activate dff
```

**Data download scripts** - all take watershed group codes as argument:
```bash
# Download from BC Data Catalogue (bcdata/WFS)
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'"

# Download from Freshwater Atlas API
time ./rfp_source_fwa.sh "'BULK', 'MORR'"

# Download from AWS (bcfishpass, habitat rasters)
time ./rfp_source_aws.sh "'BULK', 'KLUM'"
```

**Create new QGIS project**:
```bash
# Args: project_directory_name, qgis_template_file
time ./rfp_qgis_create.sh "project_name" "bcrestoration_mobile.qgs"
```

**Full workflow** (creates new project with all data):
```bash
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'" && \
time ./rfp_source_aws.sh "'BULK', 'KLUM'" && \
time ./rfp_source_fwa.sh "'BULK', 'KLUM'" && \
time ./rfp_qgis_create.sh "project_name" "bcrestoration_mobile.qgs"
```

**Update existing project**:
```bash
# Copy gpkg from existing project to scripts/qgis/
cp ~/Projects/gis/existing_project/background_layers.gpkg ~/Projects/repo/dff-2022/scripts/qgis/

# Run update with "update" flag
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'" "update"
time ./rfp_source_aws.sh "'BULK', 'KLUM'"

# Copy back
mv ~/Projects/repo/dff-2022/scripts/qgis/background_layers.gpkg ~/Projects/gis/existing_project/
```

## Important Paths

- **QGIS templates**: `data/qgis/bcfishpass_mobile.qgs`, `data/qgis/bcrestoration_mobile.qgs`
- **Form styling**: `data/qgis/*.qml` files
- **Form templates**: `data/qgis/form_*.gpkg`
- **Provincial templates**: `data/FDS_Template2021-01-28.xls`, `data/pscis_assessment_template_v24.xlsm`
- **Layer lists**: `scripts/qgis/rfp_source_bcdata.txt`, `scripts/qgis/rfp_source_fwa.txt`

## R Dependencies

Key R packages: `tidyverse`, `sf`, `fpr` (NewGraphEnvironment package), `readxl`, `bcdata`, `RPostgres`, `DBI`

Load packages via `source('scripts/packages.R')`.

The `fpr` package provides functions like `fpr_import_pscis_all()` and `fpr_import_hab_con()` for importing provincial templates.

## Python/Conda Environment

Single unified conda environment `dff` (root `environment.yml`):
- Supports both QGIS project creation (rfp scripts) and Mergin Maps sync
- Includes: GDAL/fiona/rasterio CLI tools, mergin-client, bcdata
- Create: `conda env create -f environment.yml`
- Activate: `conda activate dff`

## Output Structure

Created QGIS projects go to `~/Projects/gis/{project_name}/` containing:
- `background_layers.gpkg` - BC government spatial layers clipped to watershed groups
- `habitat_lateral.tif` - Habitat raster
- `form_pscis.gpkg`, `form_fiss_site.gpkg` - Field form layers
- `{project_name}.qgs` - QGIS project file
- `ignore_mobile/` - Methods docs and templates (not synced to phones)

## Pending Tasks

### Performance Testing
- **TODO**: Resolve #189 (handle veg_comp layer as unzipped .fgb) - may be fixed upstream
- **DONE**: ✅ Run clean performance tests without veg_comp errors (#188)
- **TODO**: Test both methods (streaming vs download-first) with network contention (S3 backup running)

### SRED Documentation
- **DONE**: ✅ Update commit-sred skill to be project/milestone aware
- **DONE**: ✅ Create SRED issue for performance benchmarking methodology (sred-2025-2026#8)

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# NewGraph Environment Conventions

Core patterns for professional, efficient workflows across NewGraph repositories.

## Issue Creation Guidelines

### Professional Issue Writing

Write issues with clear technical focus:

- **Use normal technical language** in titles and descriptions
- **Focus on the problem and solution** approach
- **Avoid internal project codes or tracking references** in the main description
- **Add tracking links at the end** if needed (e.g., `Relates to Owner/repo#N`)

**Why:** Issues are read by consultants, clients, and collaborators. Keep them professional and focused on technical content.

**Example:**
```markdown
## Problem
The DEM processing pipeline is slow for large datasets.

## Proposed Solution
Add structured logging and performance benchmarking to identify bottlenecks.
```

### GitHub Issue Creation - Always Use Files

The `gh issue create` command with heredoc syntax fails repeatedly with EOF errors. ALWAYS use intermediate file approach:

```bash
# Write issue body to scratchpad file first
cat > /path/to/scratchpad/issue_body.md << 'EOF'
## Problem
...

## Proposed Solution
...
EOF

# Then create issue from file
gh issue create --title "Brief technical title" --body-file /path/to/scratchpad/issue_body.md
```

**Why:** Reliable, works every time, no syntax errors. Saves time and tokens.

## Commit Quality

Write clear, informative commit messages:

```
Brief description (50 chars or less)

Detailed explanation of changes and impact.
- What changed
- Why it changed
- Relevant context

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**When to commit:**
- Logical, atomic units of work
- Working state (tests pass)
- Clear description of changes

**What to avoid:**
- "WIP" or "temp" commits in main branch
- Combining unrelated changes
- Vague messages like "fixes" or "updates"
