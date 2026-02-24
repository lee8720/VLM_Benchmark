# ============================================================
# File: compute_accuracy_agreement_kappa_bootstrap.R
# Purpose:
#   Compute:
#   - Top-1 accuracy (case-averaged) + bootstrap 95% CI
#   - Top-3 hit rate (case-averaged) + bootstrap 95% CI
#   - Agreement proportions (3/3, 2/3, 1/3)
#   - Fleiss' kappa + bootstrap 95% CI (case-level resampling)
#
# Input:
#   Thoracic_VLM_Benchmark_Model_Outputs_With_Rationales.xlsx
#
# Output:
#   Computed_summary_R.xlsx
# ============================================================


install.packages("openxlsx")
library(openxlsx)

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(stringr)
  library(purrr)
  library(openxlsx)
})

INFILE  <- "Thoracic_VLM_Benchmark_Model_Outputs_With_Rationales.xlsx"
OUTFILE <- "Computed_summary_R.xlsx"

N_BOOT <- 1000
SEED   <- 42

# -----------------------------
# Helper: bootstrap CI for mean
# -----------------------------
boot_ci_mean <- function(x, n_boot = 1000, seed = 42) {
  set.seed(seed)
  x <- as.numeric(x)
  n <- length(x)
  boots <- replicate(n_boot, mean(sample(x, size = n, replace = TRUE)))
  c(lower = unname(quantile(boots, 0.025)),
    upper = unname(quantile(boots, 0.975)))
}

# -----------------------------
# Fleiss' kappa from case counts
# case_counts: list of integer vectors, each sums to n_raters (=3)
# -----------------------------
fleiss_kappa_from_case_counts <- function(case_counts) {
  N <- length(case_counts)
  if (N == 0) return(NA_real_)
  n <- sum(case_counts[[1]])

  # P_i for each case
  P_i <- sapply(case_counts, function(cnt) {
    s <- sum(cnt * (cnt - 1))
    s / (n * (n - 1))
  })
  Pbar <- mean(P_i)

  # p_j across all cases
  mat <- do.call(rbind, lapply(case_counts, as.numeric))
  totals <- colSums(mat)
  p_j <- totals / (N * n)
  Pe <- sum(p_j^2)

  denom <- 1 - Pe
  if (denom <= 0) return(NA_real_)
  (Pbar - Pe) / denom
}

# -----------------------------
# Build case counts + agreement buckets for Diagnosis_norm
# -----------------------------
build_case_counts <- function(df_one, label_col = "Diagnosis_norm") {
  # categories in this model/input
  cats <- sort(unique(df_one[[label_col]]))
  idx <- setNames(seq_along(cats), cats)

  # per case: counts across 3 runs
  per_case <- df_one %>%
    arrange(Case_Number, Run) %>%
    group_by(Case_Number) %>%
    summarise(vals = list(.data[[label_col]]), .groups = "drop")

  case_counts <- map(per_case$vals, function(v) {
    cnt <- integer(length(cats))
    for (lab in v) cnt[idx[[lab]]] <- cnt[idx[[lab]]] + 1L
    cnt
  })

  # agreement buckets
  max_counts <- map_int(case_counts, max)
  full <- sum(max_counts == 3L)
  maj  <- sum(max_counts == 2L)
  no   <- sum(max_counts <= 1L)

  list(case_counts = case_counts,
       full = full, maj = maj, no = no,
       n_cats = length(cats),
       n_cases = nrow(per_case))
}

# -----------------------------
# Bootstrap CI for Fleiss' kappa (case-level resampling)
# -----------------------------
boot_ci_kappa <- function(case_counts, n_boot = 1000, seed = 42) {
  set.seed(seed)
  N <- length(case_counts)
  idx <- seq_len(N)

  boots <- replicate(n_boot, {
    sidx <- sample(idx, size = N, replace = TRUE)
    fleiss_kappa_from_case_counts(case_counts[sidx])
  })

  c(lower = unname(quantile(boots, 0.025, na.rm = TRUE)),
    upper = unname(quantile(boots, 0.975, na.rm = TRUE)))
}

# -----------------------------
# Load & clean
# -----------------------------
df <- read_excel(INFILE) %>%
  mutate(
    model = str_trim(as.character(model)),
    input = str_trim(as.character(input)),
    Diagnosis_norm = str_trim(as.character(Diagnosis_norm))
  )

# sanity: must have 3 runs per model/input/case
check <- df %>%
  count(model, input, Case_Number) %>%
  summarise(all_three = all(n == 3)) %>%
  pull(all_three)
stopifnot(check)

# -----------------------------
# Compute summary per model × input
# -----------------------------
summary <- df %>%
  group_by(model, input) %>%
  group_modify(~{
    g <- .x

    # Case-level accuracy (average across 3 runs)
    case_top1 <- g %>% group_by(Case_Number) %>% summarise(v = mean(top1_correct), .groups="drop") %>% pull(v)
    case_top3 <- g %>% group_by(Case_Number) %>% summarise(v = mean(top3_hit),      .groups="drop") %>% pull(v)

    top1_mean <- mean(case_top1)
    top3_mean <- mean(case_top3)

    top1_ci <- boot_ci_mean(case_top1, n_boot = N_BOOT, seed = SEED)
    top3_ci <- boot_ci_mean(case_top3, n_boot = N_BOOT, seed = SEED)

    # Agreement + Fleiss kappa on Diagnosis_norm (top-1 predicted label)
    cc <- build_case_counts(g, label_col = "Diagnosis_norm")
    kappa <- fleiss_kappa_from_case_counts(cc$case_counts)
    k_ci  <- boot_ci_kappa(cc$case_counts, n_boot = N_BOOT, seed = SEED)

    tibble(
      N_cases = cc$n_cases,
      Top1_accuracy_caseAvg = round(top1_mean, 3),
      Top1_boot_CI2.5  = round(top1_ci["lower"], 3),
      Top1_boot_CI97.5 = round(top1_ci["upper"], 3),
      Top3_hit_caseAvg = round(top3_mean, 3),
      Top3_boot_CI2.5  = round(top3_ci["lower"], 3),
      Top3_boot_CI97.5 = round(top3_ci["upper"], 3),
      Unique_output_labels = cc$n_cats,
      Agreement_3of3_pct = round(100 * cc$full / cc$n_cases, 1),
      Agreement_2of3_pct = round(100 * cc$maj  / cc$n_cases, 1),
      Agreement_1of3_pct = round(100 * cc$no   / cc$n_cases, 1),
      Fleiss_kappa = round(kappa, 3),
      Kappa_boot_CI2.5  = round(k_ci["lower"], 3),
      Kappa_boot_CI97.5 = round(k_ci["upper"], 3)
    )
  }) %>%
  ungroup() %>%
  arrange(input, model)

print(summary)

# -----------------------------
# Save to Excel
# -----------------------------
wb <- createWorkbook()
addWorksheet(wb, "summary")
writeData(wb, "summary", summary)
saveWorkbook(wb, OUTFILE, overwrite = TRUE)

cat("Saved:", OUTFILE, "\n")