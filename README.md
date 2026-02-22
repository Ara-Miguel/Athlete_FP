# Athlete_FP
This is an individual athlete dashboard to identify countermovement jump trends over a longitudinal timeline. Nomenclature for metrics are from VALD systems. Claude Sonnet 4.6 was utilized to create this code.

# Force Plate Longitudinal Monitoring Dashboard
**Athlete:** MA (anonymized) · **Device:** ForceDecks (VALD) · **Test:** CMJ only  
**Season:** Apr 10 – Sep 8, 2025 · **Sessions:** 32 · **Total Reps:** 60 (1–3 per session)

---

## Setup

Update `DATA_PATH` in the setup chunk before knitting `ma_longitudinal.Rmd`:

```r
DATA_PATH <- "ma_force_plate.csv"          # Option A: set working dir to source location
DATA_PATH <- "/full/path/to/file.csv"      # Option B: absolute path
DATA_PATH <- here("data", "ma_force_plate.csv")  # Option C: RStudio Project (recommended)
```

**Dependencies:** `flexdashboard`, `tidyverse`, `plotly`, `DT`

On load, the dashboard validates all 33 expected columns, confirms a non-empty CSV, and filters to `test_type == "CMJ"` — future exports containing additional test types (SJ, IMTP) will not contaminate the output.

---

## Data Representation

Every chart uses a consistent two-trace system:

| Trace | Visual | Description |
|-------|--------|-------------|
| **Other reps** | Blue markers, 35% opacity | All non-best reps; shows within-session variability |
| **Best rep / session** | Green markers + LOESS smooth | Highest JH rep per session; LOESS span = 0.5 shows season arc |

The best rep is identified per `Date + test_type`. Ties (two reps sharing the top JH) both receive `is_best_rep = TRUE`. Rep numbering (`rep_num = 1, 2, 3`) reflects chronological order within session — raw ForceDecks exports store reps newest-first; the cleaning script re-sorts by parsed datetime before numbering.

---

## Season Phases

| Phase | Dates | Sessions | Reps | Colour |
|-------|-------|----------|------|--------|
| Early Season | Apr 10 – May 31 | 14 | 30 | Blue `#2563a8` |
| Mid Season | Jun 1 – Jul 31 | 10 | 20 | Green `#1a6b3c` |
| Late Season | Aug 1 – Sep 8 | 8 | 10 | Red `#c0392b` |

A fourth "Peak" band (Jul 15–31) was evaluated but contained only 1 session and 2 reps — insufficient for a meaningful category. Merged into Mid Season.

---

## Tab 1 — Season Overview

### Jump Height — Every Rep · Best Rep per Session Connected
Timeline of all 60 reps. Season high **61.72 cm** on Jul 9, 2025. First-to-last best-rep change: **+0.76 cm**. A callout annotation marks the season high; subtitle reports session count, rep count, season high, and first→last delta — all computed dynamically.

> **Hover:** Date · Rep X of Y · Jump height (cm) · RSI (m/s)  
> *Rep count per session is derived from the data, not the raw ForceDecks `Reps` field, which is an unreliable per-row internal counter.*

### RSI-Modified — Every Rep · Season Trajectory
RSI-Mod = Jump Height (m) ÷ Contraction Time (s). Captures height produced per unit of ground contact time — a higher value means more efficient neuromuscular output. An amber dashed reference line at **0.75 m/s** marks the threshold for high reactive strength in trained athletes. Season high 0.850 m/s; first-to-last change: −0.010 m/s (effectively stable).

### Jump Height Distribution by Month
Box plots with jittered individual rep points, coloured by phase. Month order is derived from sorted dates at load time — not dependent on CSV row order.

### Phase Summary — Best Rep Stats
DataTable of best-rep means and bests by phase. Mid Season leads all metrics: best JH 61.7 cm vs 58.7 cm (Early) and 56.4 cm (Late).

---

## Tab 2 — Trajectories

All four charts use the same two-trace structure as Season Overview.

### Eccentric RFD — Every Rep · Season Trajectory
Rate of force development during the eccentric (loading) phase, in N/s. Reflects how quickly the neuromuscular system generates force under stretch — a proxy for reactive ability and stretch-shortening cycle efficiency. Season range: 5,866–12,210 N/s. **r = +0.758** vs jump height (p < 0.001).

### Concentric Peak Force / BM — Every Rep
Peak concentric force normalised to body mass (N/kg). Normalising removes session-to-session weight fluctuation and allows size-independent comparison. Season range: 25.6–38.6 N/kg. **r = +0.758** vs jump height (p < 0.001).

### CMJ Stiffness — Every Rep
Leg spring stiffness during the countermovement (N/m) — the ratio of peak GRF to peak CoM displacement. Higher stiffness = more efficient elastic energy storage. Sensitive to neuromuscular fatigue. Season range: 5,123–6,657 N/m. **r = +0.597** vs jump height (p < 0.001).

### eRFD vs Jump Height — All Reps · Colored by Phase
Cross-sectional scatter: eRFD on X, jump height on Y. Filled circles = best reps; open circles = other reps. Shows that high eRFD co-occurs with high jump height on the same rep, not just over time.

---

## Tab 3 — Asymmetry

All asymmetry metrics derive from left and right concentric peak force (`cpf_l`, `cpf_r`) measured on separate force plates.

**Formula:** `asym_concentric_pct = (cpf_l − cpf_r) / max(cpf_l, cpf_r) × 100`  
Positive = left dominant · Negative = right dominant · Denominator uses the stronger limb (not the sum), which is standard practice and avoids understating asymmetry.  
A divide-by-zero guard returns `NA_real_` if both limb forces are zero; all `mean()` calculations include `na.rm = TRUE`.

### Concentric Asymmetry (L vs R) — Every Rep · ±10% Threshold
All 60 reps plotted over time, coloured by phase. Red dashed lines at ±10% mark the clinical threshold for meaningful asymmetry. **Mean absolute asymmetry: 2.8%. Maximum: 9.2%. Zero reps exceeded the ±10% threshold** — an unusually clean bilateral profile.

### Left vs Right Concentric Peak Force — All Reps
Scatter of left (X) vs right (Y) CPF in Newtons. The grey dashed diagonal = perfect symmetry. Shows whether asymmetry is driven by force increasing on one limb or decreasing on the other.

### Asymmetry Distribution by Phase
Box plots of absolute asymmetry (`asym_abs_pct`) by phase, with individual reps overlaid. The 10% threshold segment uses `x = 0.5, xend = 3.5` — spanning the three phase boxes only.

### L/R Force — Monthly Means
Grouped bar chart (blue = left, red = right) of mean CPF by calendar month across all reps. Shows temporal trends in absolute bilateral force levels.

---

## Tab 4 — Impulse Correlation

### Concentric Impulse 50ms & 100ms vs Jump Height
Impulse = force × time (N·s). By Newton's second law (J = mΔv), greater early impulse means faster upward CoM acceleration at takeoff. Both scatter plots are coloured by phase; filled = best rep, open = other rep.

| Metric | r vs JH | p |
|--------|---------|---|
| Conc Impulse 100ms | **+0.843** | < 0.001 |
| Conc Impulse 50ms | **+0.799** | < 0.001 |

The 100ms window is the **strongest single predictor** of jump height in this dataset.

### Impulse 50ms & 100ms — Season Trajectory
Dual-axis timeline: 50ms on the left axis (blue), 100ms on the right axis (green). LOESS smooths (`span = 0.45`) are fitted to **all reps** here — appropriate because the question is general impulse trend, not peak capacity. Clicking a legend entry toggles both the raw markers and the LOESS line together via `legendgroup`.

### Impulse Correlation Summary — All Metrics vs Jump Height
Horizontal bar chart ranking all eight metrics by Pearson r with jump height.

| Metric | r | Note |
|--------|---|------|
| Conc Impulse 100ms | +0.843 | Strongest predictor |
| Conc Impulse 50ms | +0.799 | |
| Eccentric RFD | +0.758 | |
| CPF / BM | +0.758 | |
| CMJ Stiffness | +0.597 | |
| RSI-Modified | +0.367 | |
| Conc RFD 100ms | −0.688 | Negative by ForceDecks convention only |
| Conc RFD 50ms | −0.664 | Negative by ForceDecks convention only |

Conc RFD negative values are a sign convention artefact in ForceDecks — not a true inverse relationship. Interpret by |r|. The zero-line is drawn with categorical Y anchors (`corr_df$metric[nrow(corr_df)]` to `corr_df$metric[1]`) to avoid stray numeric tick labels on the Y-axis.

---

## Tab 5 — Rep Detail

Interactive DataTable of all 60 reps. Default sort: newest session first, rep number ascending within session.

| Column | Unit | Notes |
|--------|------|-------|
| Date | — | Display format: Mon DD, YYYY. Sorts via hidden ISO `date_sort` column |
| Sess | integer | Session number, 1–32 chronologically |
| Rep | integer | Rep number within session; 1 = first rep by time of day |
| Best | ★ / — | Flags highest-JH rep per session |
| JH (cm) | cm | Jump height |
| RSI (m/s) | m/s | RSI-Modified |
| eRFD (N/s) | N/s | Eccentric RFD |
| Stiffness (N/m) | N/m | CMJ leg spring stiffness |
| CPF/BM (N/kg) | N/kg | Concentric peak force / body mass |
| CM Depth (cm) | cm | Countermovement depth |
| L Force (N) | N | Left limb concentric peak force |
| R Force (N) | N | Right limb concentric peak force |
| Asym % | % | Signed asymmetry; range −9.2% to +9.2% this season |
| BW (kg) | kg | Body weight at test |

Export to CSV or Excel via the Buttons extension. The hidden `date_sort` column is excluded from exports.

---

## Colour Reference

| Constant | Hex | Used for |
|----------|-----|----------|
| `COL_ALL` | `#2563a8` | Other reps / Early Season |
| `COL_BEST` | `#1a6b3c` | Best rep / Mid Season / positive r |
| `COL_NEG` | `#c0392b` | Late Season / negative r / asym threshold |
| `COL_IMPULSE` | `#7b2d8b` | Impulse bars in correlation summary |
| `COL_WARN` | `#c07a1a` | Reference lines (RSI 0.75 threshold) |
| `COL_MUTED` | `#555550` | Subtitle annotations / secondary labels |
| `COL_PAPER` | `#faf8f3` | Plot and page background |
| `COL_BORDER` | `#ccc9c0` | Grid lines |

All colors are defined as named constants in the setup chunk. No hex literals appear in the chart layer.

---

*All figures computed from `ma_force_plate.csv` · 60 reps · 32 sessions · CMJ only · ForceDecks (VALD) · Apr 10 – Sep 8, 2025*
