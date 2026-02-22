# =============================================================================
# MA FORCE PLATE — DATA CLEANING SCRIPT
# =============================================================================
# Input  : Raw ForceDecks export CSV (from VALD ForceDecks software)
# Output : ma_force_plate.csv — individual rep level, cleaned and annotated
#
# Execution order:
#   1.  Set paths
#   2.  Load raw data
#   3.  Validate required columns exist before any rename
#   4.  Parse dates and sort chronologically
#   5.  Anonymize athlete name → "MA"
#   6.  Rename columns to clean R-friendly names
#   7.  Drop columns that are structurally empty (ExternalId, Tags)
#   8.  Drop Additional Load only if all-zero; warn and retain if loaded jumps present
#   9.  Convert jump height inches → centimeters
#   10. Assign session numbers (scoped to Date + test_type)
#   11. Assign rep numbers within each session (scoped to Date + test_type)
#   12. Flag best rep per session (scoped to Date + test_type; ties both flagged TRUE)
#   13. Compute L/R concentric asymmetry % (divide-by-zero guarded)
#   14. Add month label for grouping/plotting
#   15. Validate Reps column and select final columns
#   16. Run final checks and save
#
# Notes:
#   - No rows are removed — all reps are kept
#   - No session averaging — rep-level data preserved intentionally
#   - Asymmetry sign convention: positive = left dominant
#   - jump_height_in retained alongside jump_height_cm to preserve source unit
#     and allow conversion verification without re-running the export
#   - Reps column is a raw ForceDecks per-row field; rep_num (derived here) is
#     the authoritative rep count within each session
#   - asym_abs_pct is the absolute value of concentric asymmetry only;
#     takeoff asymmetry (asym_takeoff_pct) is retained separately
# =============================================================================

library(tidyverse)
library(lubridate)

# =============================================================================
# STEP 1: Set paths
# =============================================================================
# Option A (simplest) — set your working directory in RStudio via
#   Session → Set Working Directory → To Source File Location
# then use relative paths (default below):
#
#   RAW_PATH <- "MA_-_forcedecks-test-export-09_19_2025__3_.csv"
#   OUT_PATH <- "ma_force_plate.csv"
#
# Option B — absolute paths (update to your machine):
#
#   RAW_PATH <- "/Users/yourname/data/MA_-_forcedecks-test-export-09_19_2025__3_.csv"
#   OUT_PATH <- "/Users/yourname/data/ma_force_plate.csv"
#
# Option C — use the here package for project-relative paths (recommended
# if this script lives inside an RStudio Project):
#
#   library(here)
#   RAW_PATH <- here("data", "MA_-_forcedecks-test-export-09_19_2025__3_.csv")
#   OUT_PATH <- here("data", "ma_force_plate.csv")

RAW_PATH <- "MA_-_forcedecks-test-export-09_19_2025__3_.csv"  # <- update as needed
OUT_PATH <- "ma_force_plate.csv"                               # <- update as needed

# =============================================================================
# STEP 2: Load raw data
# =============================================================================
raw <- read_csv(RAW_PATH, show_col_types = FALSE)

cat(sprintf("Loaded: %d rows x %d columns\n", nrow(raw), ncol(raw)))
cat(sprintf("Test types: %s\n", paste(unique(raw$`Test Type`), collapse = ", ")))

# =============================================================================
# STEP 3: Validate required raw column names before rename
# =============================================================================
# ForceDecks export column names include brackets and spacing that can change
# across VALD software versions. Checking upfront gives a clear error message
# listing exactly which columns are missing rather than a cryptic rename()
# failure mid-script.
required_raw_cols <- c(
  "Date", "Time", "Name", "Test Type", "Reps",
  "BW [KG]", "Additional Load [lb]",
  "Braking Phase Duration [ms]",
  "Jump Height (Imp-Mom) in Inches [in]",
  "CMJ Stiffness [N/m]",
  "Concentric Impulse-50ms [N s]",
  "Concentric Impulse-100ms [N s]",
  "Concentric Peak Force / BM [N/kg]",
  "Concentric Peak Force [N]",
  "Concentric Peak Velocity [m/s]",
  "Concentric RFD - 50ms [N/s]",
  "Concentric RFD - 100ms [N/s]",
  "Countermovement Depth [cm]",
  "Eccentric Braking RFD [N/s]",
  "Flight Time [ms]",
  "Force at Peak Power [N]",
  "RSI-modified [m/s]",
  "Takeoff Peak Force / BM [N/kg]",
  "Concentric Peak Force [N] (L)",
  "Concentric Peak Force [N] (R)",
  "Takeoff Peak Force [N] (L)",
  "Takeoff Peak Force [N] (R)",
  "ExternalId", "Tags"
)

missing_cols <- setdiff(required_raw_cols, names(raw))
if (length(missing_cols) > 0) {
  stop(
    "The following expected columns were not found in the raw export.\n",
    "This may indicate a VALD software version change in column naming.\n",
    "Missing: ", paste(missing_cols, collapse = ", "), "\n",
    "Actual columns: ", paste(names(raw), collapse = ", ")
  )
}
cat("Column validation passed — all required columns present\n")

# =============================================================================
# STEP 4: Parse dates and sort chronologically
# =============================================================================
# lubridate::mdy() is used instead of as.Date(..., format = "%m/%d/%Y") because
# the raw ForceDecks export uses non-zero-padded dates (e.g. "9/8/2025" not
# "09/08/2025"). %m/%d/%Y is lenient on Mac/Linux but unreliable on Windows;
# mdy() handles both formats correctly on all platforms.
# The raw ForceDecks export stores reps in REVERSE chronological order within
# each session (most recent rep first). Sorting ascending by datetime ensures
# rep_num 1 = the first rep of the session chronologically.
# parse_date_time() handles the 12-hour AM/PM format ("8:07 AM") cleanly.
df <- raw |>
  mutate(
    Date     = mdy(Date),
    datetime = parse_date_time(paste(as.character(mdy(Date)), Time),
                               orders = "Ymd I:M p")
  ) |>
  arrange(Date, `Test Type`, datetime)

cat(sprintf("Date range: %s -> %s\n", min(df$Date), max(df$Date)))

# =============================================================================
# STEP 5: Anonymize
# =============================================================================
df <- df |>
  mutate(Name = "MA")

# =============================================================================
# STEP 6: Rename columns to clean R-friendly names
# =============================================================================
df <- df |>
  rename(
    test_type           = `Test Type`,
    bw_kg               = `BW [KG]`,
    additional_load_lb  = `Additional Load [lb]`,
    braking_dur_ms      = `Braking Phase Duration [ms]`,
    jump_height_in      = `Jump Height (Imp-Mom) in Inches [in]`,
    cmj_stiffness       = `CMJ Stiffness [N/m]`,
    conc_impulse_50ms   = `Concentric Impulse-50ms [N s]`,
    conc_impulse_100ms  = `Concentric Impulse-100ms [N s]`,
    cpf_bm              = `Concentric Peak Force / BM [N/kg]`,
    cpf_n               = `Concentric Peak Force [N]`,
    conc_velocity       = `Concentric Peak Velocity [m/s]`,
    conc_rfd_50ms       = `Concentric RFD - 50ms [N/s]`,
    conc_rfd_100ms      = `Concentric RFD - 100ms [N/s]`,
    cm_depth            = `Countermovement Depth [cm]`,
    ecc_rfd             = `Eccentric Braking RFD [N/s]`,
    flight_time_ms      = `Flight Time [ms]`,
    force_at_peak_power = `Force at Peak Power [N]`,
    rsi_mod             = `RSI-modified [m/s]`,
    takeoff_pf_bm       = `Takeoff Peak Force / BM [N/kg]`,
    cpf_l               = `Concentric Peak Force [N] (L)`,
    cpf_r               = `Concentric Peak Force [N] (R)`,
    takeoff_l           = `Takeoff Peak Force [N] (L)`,
    takeoff_r           = `Takeoff Peak Force [N] (R)`
  )

# =============================================================================
# STEP 7: Drop columns that are structurally empty
# =============================================================================
# ExternalId and Tags are entirely empty in all known ForceDecks exports for
# this athlete. Dropped unconditionally as they carry no analytical value.
# Time and datetime are used only for within-session sort ordering (Step 4)
# and are not needed in the cleaned output.
df <- df |>
  select(-ExternalId, -Tags, -Time, -datetime)

# =============================================================================
# STEP 8: Drop Additional Load only if all-zero
# =============================================================================
# additional_load_lb is all zeros for bodyweight-only CMJ. If the athlete ever
# performs loaded jumps, this column becomes meaningful and must be retained.
# This check makes the decision explicit and auditable rather than silent.
if (all(df$additional_load_lb == 0, na.rm = TRUE)) {
  df <- df |> select(-additional_load_lb)
  cat("Additional Load column dropped — all values are zero (bodyweight-only tests)\n")
} else {
  loaded_n <- sum(df$additional_load_lb != 0, na.rm = TRUE)
  cat(sprintf(
    "WARNING: %d rep(s) have non-zero Additional Load — column retained.\n",
    loaded_n
  ))
}

# =============================================================================
# STEP 9: Convert jump height inches -> centimeters
# =============================================================================
# jump_height_in is retained as the source unit for conversion verification.
df <- df |>
  mutate(jump_height_cm = round(jump_height_in * 2.54, 2))

# =============================================================================
# STEP 10: Assign session numbers (scoped to Date + test_type)
# =============================================================================
# Scoping to both Date AND test_type ensures correct session numbering if
# future exports contain multiple test types on the same day (e.g. CMJ + SJ).
# df is already sorted by Date and test_type (Step 4), so row_number() produces
# correct sequential session labels.
session_map <- df |>
  distinct(Date, test_type) |>
  arrange(Date, test_type) |>
  mutate(session_num = row_number())

df <- df |>
  left_join(session_map, by = c("Date", "test_type"))

cat(sprintf("Unique sessions: %d\n", max(df$session_num)))

# =============================================================================
# STEP 11: Assign rep numbers within each session
# =============================================================================
# Scoped to Date + test_type for the same reason as Step 10.
# rep_num is the authoritative rep count within a session. The raw Reps column
# from ForceDecks is a per-row field that does not reliably reflect session rep
# totals — do not use it for rep counting.
df <- df |>
  group_by(Date, test_type) |>
  mutate(rep_num = row_number()) |>
  ungroup()

cat(sprintf("Max reps in a single session: %d\n", max(df$rep_num)))

# =============================================================================
# STEP 12: Flag best rep per session (highest jump height)
# =============================================================================
# Scoped to Date + test_type so best-rep comparison never crosses test types.
# Ties are both flagged TRUE — rare but handled correctly.
df <- df |>
  group_by(Date, test_type) |>
  mutate(is_best_rep = jump_height_cm == max(jump_height_cm, na.rm = TRUE)) |>
  ungroup()

cat(sprintf("Best reps flagged: %d (expect >= %d — one per session; ties count twice)\n",
            sum(df$is_best_rep), max(df$session_num)))

# =============================================================================
# STEP 13: Compute L/R asymmetry
# =============================================================================
# Formula : (L - R) / max(L, R) * 100
# Sign    : Positive = left dominant, Negative = right dominant
# Guard   : if_else(pmax(...) > 0, ..., NA_real_) prevents NaN from
#           divide-by-zero in corrupted exports where both limbs read 0.
# asym_abs_pct is derived from concentric asymmetry only; takeoff asymmetry
# (asym_takeoff_pct) is retained as a separate column for reference.
df <- df |>
  mutate(
    asym_concentric_pct = round(
      if_else(pmax(cpf_l, cpf_r) > 0,
              (cpf_l - cpf_r) / pmax(cpf_l, cpf_r) * 100,
              NA_real_),
      2),
    asym_takeoff_pct = round(
      if_else(pmax(takeoff_l, takeoff_r) > 0,
              (takeoff_l - takeoff_r) / pmax(takeoff_l, takeoff_r) * 100,
              NA_real_),
      2),
    asym_abs_pct = abs(asym_concentric_pct)
  )

cat(sprintf("Mean absolute asymmetry: %.1f%%\n", mean(df$asym_abs_pct, na.rm = TRUE)))
cat(sprintf("Reps exceeding +/-10%% threshold: %d\n", sum(df$asym_abs_pct > 10, na.rm = TRUE)))
if (any(is.na(df$asym_concentric_pct))) {
  cat(sprintf("WARNING: %d rep(s) produced NA asymmetry (both limbs zero)\n",
              sum(is.na(df$asym_concentric_pct))))
}

# =============================================================================
# STEP 14: Add month label for grouping/plotting
# =============================================================================
# Factor levels locked to chronological order so plots display Apr->Sep
# rather than alphabetical order (Apr, Aug, Jun...).
# arrange(Date) here is explicit — does not rely on upstream sort persisting.
month_order <- df |>
  arrange(Date) |>
  pull(Date) |>
  format("%b %Y") |>
  unique()

df <- df |>
  mutate(month_label = factor(format(Date, "%b %Y"), levels = month_order))

# =============================================================================
# STEP 15: Validate Reps column and select final columns
# =============================================================================
# Reps is a raw ForceDecks per-row field retained for reference only. It does
# NOT reliably equal reps performed per session — it is a positional counter
# internal to ForceDecks. Use rep_num for all rep-level analysis.
if (!"Reps" %in% names(df)) {
  stop("Column 'Reps' not found. Check raw export column names: ",
       paste(names(df), collapse = ", "))
}
if (!is.numeric(df$Reps)) {
  warning("Reps column is not numeric — type: ", class(df$Reps))
}

df_clean <- df |>
  select(
    Name, Date, session_num, rep_num, is_best_rep, month_label,
    bw_kg, test_type, Reps,
    jump_height_in, jump_height_cm,
    rsi_mod, ecc_rfd, cmj_stiffness,
    cpf_bm, cpf_n, conc_velocity,
    braking_dur_ms, cm_depth, flight_time_ms, force_at_peak_power,
    conc_impulse_50ms, conc_impulse_100ms,
    conc_rfd_50ms, conc_rfd_100ms,
    takeoff_pf_bm,
    cpf_l, cpf_r, takeoff_l, takeoff_r,
    asym_concentric_pct, asym_takeoff_pct, asym_abs_pct
  )

# =============================================================================
# STEP 16: Final checks and save
# =============================================================================
# Peak date: use which() on the full logical vector to detect ties explicitly.
peak_jh_val  <- max(df_clean$jump_height_cm, na.rm = TRUE)
peak_jh_idx  <- which(df_clean$jump_height_cm == peak_jh_val)
peak_jh_date <- format(df_clean$Date[peak_jh_idx[1]], "%b %d")
peak_jh_note <- if (length(peak_jh_idx) > 1) {
  sprintf("(tied across %d reps)", length(peak_jh_idx))
} else {
  ""
}

cat("\n=== CLEANING SUMMARY ===\n")
cat(sprintf("Rows (reps):      %d\n",  nrow(df_clean)))
cat(sprintf("Columns:          %d\n",  ncol(df_clean)))
cat(sprintf("Sessions:         %d\n",  n_distinct(df_clean$Date)))
cat(sprintf("Date range:       %s -> %s\n",
            format(min(df_clean$Date), "%b %d, %Y"),
            format(max(df_clean$Date), "%b %d, %Y")))
cat(sprintf("Missing values:   %d\n",  sum(is.na(df_clean))))
cat(sprintf("Season high JH:   %.2f cm (%s) %s\n",
            peak_jh_val, peak_jh_date, peak_jh_note))
cat(sprintf("Peak RSI:         %.2f m/s\n",
            max(df_clean$rsi_mod, na.rm = TRUE)))

write_csv(df_clean, OUT_PATH)
cat(sprintf("\nSaved: %s\n", OUT_PATH))
