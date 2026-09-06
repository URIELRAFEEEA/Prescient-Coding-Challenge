# -----------------------------------------------------------------------------
# Prescient Coding Challenge 2026 -- your submission (R).
#
# THIS IS THE ONLY FILE YOU MAY CHANGE.
#
# You implement one function. The harness calls it once per trading day and
# hands you a `hist` list holding every observation STRICTLY BEFORE that day.
# You return the weights you want to hold for that day.
#
#     generate_weights(hist, prev_weights, params) -> named numeric vector
#
# What you get
# ------------
# hist$date                 the day you are allocating for (no data for it yet)
# hist$returns              matrix [date x asset] of daily returns, decimals
# hist$prices               matrix [date x asset] of total-return index levels
# hist$macro                matrix [date x macro feature]
# hist$assets               the six asset codes, in order
# hist$benchmark            named vector of benchmark weights
# hist$active_weight(w)     total active weight of w -- the number rule 3 tests
#
# prev_weights              what you held yesterday. Trading away from it costs
#                           money, so look at it.
# params                    the PARAMS list below, passed straight through
#
# What you must return
# --------------------
# Six weights (named numeric vector) that sum to 1, are all non-negative, sit
# within 10% of their benchmark weight, have a total active weight of no more
# than 40%, keep total equity at or below 75% and gold at or below 10%.
# make_legal() below already does all of that -- you can leave it alone.
#
# Declare every tuneable number in PARAMS. Parameter count is part of the score.
#
# Run `Rscript harness.R` to test on the practice window (calendar 2025), then
# `Rscript validate.R` before you submit.
# -----------------------------------------------------------------------------

# ---- Every tuneable number lives here. Fewer is better. ---------------------

PARAMS <- list(
  mom_days          = 60,    # lookback for cross-asset risk-adjusted momentum
  short_days        = 5,     # lookback for the short-term reversal dampener
  macro_fast        = 20,    # fast MA window for macro/FX momentum
  macro_slow        = 100,   # slow MA window for macro/FX momentum
  macro_weight      = 0.65,  # macro tilt vs cross-asset momentum
  reversion_weight  = 0.35,  # strength of short-term reversal
  tilt_size         = 0.05,  # overall signal -> active-weight scaling
  trade_speed       = 0.10   # fraction of gap to yesterday closed per day
)

# The rules, restated locally so this file reads on its own.
ACTIVE_BAND   <- 0.10
ACTIVE_BUDGET <- 0.40
EQUITY        <- c("SA_EQUITY", "GLOBAL_EQUITY")
EQUITY_CAP    <- 0.75
GOLD_CAP      <- 0.10


# -----------------------------------------------------------------------------
# YOUR CODE GOES BELOW THIS LINE
# -----------------------------------------------------------------------------


#' Cross-sectional standardisation.
#'
#' Flat input -> all zeros.
zscore <- function(x) {
  x <- as.numeric(x)
  
  s <- sd(x, na.rm = TRUE)
  
  if (!is.finite(s) || s < 1e-12) {
    return(rep(0, length(x)))
  }
  
  (x - mean(x, na.rm = TRUE)) / s
}


#' Standardised fast-MA minus slow-MA.
#'
#' Compares the current fast-MA minus slow-MA gap with the historical
#' standard deviation of that same gap.
ma_diff_z <- function(series, fast, slow) {
  
  series <- as.numeric(series)
  series <- series[is.finite(series)]
  
  if (length(series) < slow + 20) {
    return(0)
  }
  
  # Explicit equivalent of pandas:
  # s.rolling(fast).mean()
  # s.rolling(slow).mean()
  fast_ma <- rep(NA_real_, length(series))
  slow_ma <- rep(NA_real_, length(series))
  
  for (i in fast:length(series)) {
    fast_ma[i] <- mean(series[(i - fast + 1):i])
  }
  
  for (i in slow:length(series)) {
    slow_ma[i] <- mean(series[(i - slow + 1):i])
  }
  
  gap <- fast_ma - slow_ma
  gap <- gap[is.finite(gap)]
  
  if (length(gap) == 0) {
    return(0)
  }
  
  n <- length(gap)
  tail_gap <- gap[max(1, n - slow + 1):n]
  
  s <- sd(tail_gap)
  
  if (!is.finite(s) || s < 1e-12) {
    return(0)
  }
  
  gap[length(gap)] / s
}



#' Score each asset.
#'
#' Positive means overweight.
#' Negative means underweight.
#'
#' Two blocks:
#
#' 1. Macro lead-lag:
#'    - USD/ZAR momentum
#'    - DXY momentum
#'    - SA 10Y yield momentum
#
#' 2. Cross-asset momentum:
#'    - medium-term risk-adjusted return
#'    - short-term reversal dampener
#
#' The two blocks are blended and standardised.
build_signal <- function(hist, params) {
  
  assets <- hist$assets
  rets   <- hist$returns
  macro  <- hist$macro
  
  mom_days <- as.integer(params$mom_days)
  short_days <- as.integer(params$short_days)
  fast <- as.integer(params$macro_fast)
  slow <- as.integer(params$macro_slow)
  
  # Make sure the matrices are treated as matrices.
  rets <- as.matrix(rets)
  macro <- as.matrix(macro)
  
  # ---------------- Block 1: macro lead-lag ---------------- #
  
  usdzar_mom <- ma_diff_z(
    macro[, "usdzar"],
    fast,
    slow
  )
  
  dxy_mom <- ma_diff_z(
    macro[, "dxy"],
    fast,
    slow
  )
  
  rate_trend <- ma_diff_z(
    macro[, "sa_10y"],
    fast,
    slow
  )
  
  
  macro_score <- setNames(
    rep(0, length(assets)),
    assets
  )
  
  
  # Rand weakness lifts the ZAR value of foreign/hard assets.
  # Dollar strength is a broad EM/risk-asset headwind.
  
  macro_score["GLOBAL_EQUITY"] <-
    macro_score["GLOBAL_EQUITY"] +
    usdzar_mom -
    0.5 * dxy_mom
  
  macro_score["SA_EQUITY"] <-
    macro_score["SA_EQUITY"] -
    0.3 * dxy_mom
  
  macro_score["SA_CASH"] <-
    macro_score["SA_CASH"] +
    0.3 * dxy_mom
  
  # Gold, bonds and property are long-duration assets.
  
  macro_score["GOLD"] <-
    macro_score["GOLD"] +
    0.7 * usdzar_mom -
    0.4 * rate_trend
  
  macro_score["SA_BONDS"] <-
    macro_score["SA_BONDS"] -
    0.4 * rate_trend
  
  macro_score["SA_PROPERTY"] <-
    macro_score["SA_PROPERTY"] -
    0.4 * rate_trend
  
  
  macro_z <- zscore(macro_score)
  names(macro_z) <- assets
  
  
  # ---------------- Block 2: cross-asset momentum ---------------- #
  
  n <- nrow(rets)
  start <- max(1, n - mom_days + 1)
  
  r_mom <- rets[start:n, , drop = FALSE]
  
  # Python:
  # ann_mean = r_mom.mean() * 252
  # ann_vol = r_mom.std() * sqrt(252)
  
  ann_mean <- colMeans(r_mom, na.rm = TRUE) * 252
  
  ann_vol <- apply(
    r_mom,
    2,
    sd,
    na.rm = TRUE
  ) * sqrt(252)
  
  
  sharpe <- ann_mean / ann_vol
  
  sharpe[!is.finite(sharpe)] <- 0
  
  sharpe <- sharpe[assets]
  
  
  # Short-term return.
  start_short <- max(1, n - short_days + 1)
  
  short_ret <- colMeans(
    rets[start_short:n, , drop = FALSE],
    na.rm = TRUE
  )
  
  short_ret <- short_ret[assets]
  short_ret[!is.finite(short_ret)] <- 0
  
  
  # Recent spike -> positive reversal score -> fade it.
  reversal <- zscore(short_ret)
  names(reversal) <- assets
  
  
  # Python:
  # momentum_score =
  #     _zscore(sharpe) -
  #     reversion_weight * reversal
  
  momentum_score <-
    zscore(sharpe) -
    as.numeric(params$reversion_weight) * reversal
  
  names(momentum_score) <- assets
  
  momentum_z <- zscore(momentum_score)
  names(momentum_z) <- assets
  
  
  # ---------------- Combine ---------------- #
  
  w <- as.numeric(params$macro_weight)
  
  composite <-
    w * macro_z +
    (1 - w) * momentum_z
  
  composite <- zscore(composite)
  
  names(composite) <- assets
  
  composite[!is.finite(composite)] <- 0
  
  composite
}


#' Force `weights` to satisfy every rule.
#'
#' This is the original R plumbing supplied by the challenge.
#' It has not been changed.
make_legal <- function(weights, hist) {
  
  bm <- hist$benchmark
  
  active <- weights[hist$assets] - bm
  
  for (i in 1:50) {
    
    active <- pmin(
      pmax(active, -ACTIVE_BAND),
      ACTIVE_BAND
    )
    
    active <- pmax(
      active,
      -bm
    )
    
    # Rule 4: total equity cap.
    eq_excess <-
      sum(
        bm[EQUITY] +
          active[EQUITY]
      ) -
      EQUITY_CAP
    
    eq_full <- eq_excess > -1e-12
    
    if (eq_excess > 0) {
      
      floor <- pmax(
        -ACTIVE_BAND,
        -bm[EQUITY]
      )
      
      down <- pmax(
        active[EQUITY] - floor,
        0
      )
      
      if (sum(down) > 1e-15) {
        
        active[EQUITY] <-
          active[EQUITY] -
          eq_excess * down / sum(down)
      }
    }
    
    # Rule 5: gold cap.
    active[["GOLD"]] <-
      min(
        active[["GOLD"]],
        GOLD_CAP - bm[["GOLD"]]
      )
    
    # Must sum to zero for weights to sum to one.
    excess <- sum(active)
    
    if (abs(excess) < 1e-12) {
      break
    }
    
    # Give correction to assets that have room.
    if (excess < 0) {
      room <- ACTIVE_BAND - active
    } else {
      room <- active + bm
    }
    
    room <- pmax(room, 0)
    
    if (excess < 0 && eq_full) {
      room[EQUITY] <- 0
    }
    
    if (sum(room) <= 1e-15) {
      break
    }
    
    active <-
      active -
      excess * room / sum(room)
  }
  
  # Rule 3: total active budget.
  total <- sum(abs(active))
  
  if (total > ACTIVE_BUDGET) {
    active <-
      active *
      (ACTIVE_BUDGET / total)
  }
  
  bm + active
}


#' Return the six portfolio weights to hold on hist$date.
generate_weights <- function(hist, prev_weights, params) {
  
  bm <- hist$benchmark
  
  # Not enough history.
  if (nrow(hist$returns) < 260) {
    return(bm)
  }
  
  # 1. Signal -> target weights around benchmark.
  signal <- build_signal(
    hist,
    params
  )
  
  target <- make_legal(
    bm +
      as.numeric(params$tilt_size) * signal,
    hist
  )
  
  # 2. Trade gradually toward target.
  prev <- prev_weights[hist$assets]
  
  w <-
    prev +
    as.numeric(params$trade_speed) *
    (target - prev)
  
  make_legal(
    w,
    hist
  )
}


# -----------------------------------------------------------------------------
# YOUR CODE GOES ABOVE THIS LINE
# -----------------------------------------------------------------------------

