# Prescient Coding Challenge 2026

## Dynamic Tactical Asset Allocation

This repository contains my solution to the **Prescient Investment Management Coding Challenge 2026**.

The challenge focuses on managing a South African balanced portfolio against a fixed multi-asset benchmark. Each trading day, the strategy uses information available up to that point to determine portfolio weights while operating within position, risk and trading-cost constraints.

The objective is to generate excess returns relative to the benchmark while maintaining disciplined portfolio construction.

---

## The Investment Problem

The benchmark consists of six asset classes:

| Asset | Benchmark Weight |
|---|---:|
| SA Equity | 40.0% |
| Global Equity | 20.0% |
| SA Bonds | 25.0% |
| SA Cash | 7.5% |
| SA Property | 5.0% |
| Gold | 2.5% |

The strategy can take active positions around these benchmark weights, subject to the portfolio constraints specified in the challenge.

Transaction costs are also incorporated into the portfolio construction process, making turnover an important consideration.

---

## Strategy

I developed a **dynamic tactical asset-allocation strategy** combining:

- market momentum;
- short-term reversal; and
- macroeconomic trends.

The strategy is built around two main signal components.

### 1. Macroeconomic Signals

The macro component uses trends in:

- USD/ZAR;
- DXY; and
- South African 10-year government bond yields.

For each variable, the strategy compares a shorter-term moving average with a longer-term moving average.

The current implementation uses:

- **20-day fast moving average**
- **100-day slow moving average**

The resulting signals are standardised and translated into asset-specific views.

For example, movements in USD/ZAR influence the allocation to global assets and gold, while South African interest-rate trends influence the allocation to bonds, property and gold.

### 2. Cross-Asset Momentum

The second component measures relative performance across the six assets.

The strategy uses a **60-day lookback** and calculates risk-adjusted momentum:

**Risk-adjusted momentum = annualised mean return / annualised volatility**

This allows recent performance to be considered while accounting for differences in asset volatility.

A short-term reversal signal based on the previous **five trading days** is also incorporated to reduce the tendency to chase very recent price movements.

---

## Signal Combination

The two signal blocks are combined into a single composite allocation signal.

The current model uses:

- **65% macroeconomic signals**
- **35% cross-asset momentum**

Conceptually:

**Composite Signal = 0.65 × Macro Signal + 0.35 × Momentum Signal**

The resulting signal is standardised before being converted into active portfolio positions.

---

## Dynamic Portfolio Construction

Rather than making large portfolio changes immediately, the strategy moves gradually towards its signal-implied target.

The portfolio adjustment follows:

w(t) = w(t-1) + λ (w*(t) w(t-1))

where:

**𝑤_𝑡**  is the portfolio weight at time **𝑡**;
**𝑤_{𝑡−1}** is the previous portfolio weight;
**𝑤∗_𝑡** is the signal-implied target;
𝜆 controls the speed of adjustment.

The current implementation uses a 10% daily adjustment towards the target.

This creates a more gradual allocation process and helps limit unnecessary turnover.

## Portfolio Constraints

The strategy incorporates the challenge's portfolio constraints through the make_legal() function.

The portfolio is required to:

remain fully invested;
remain long-only;
remain within the permitted active bands around the benchmark;
remain within the total active-weight budget;
keep total equity exposure below the specified maximum;
keep gold exposure below the specified maximum.

The legality function adjusts the proposed portfolio when necessary so that the resulting weights comply with these requirements.

## Transaction Costs

Trading costs are an important part of the challenge.

Different asset classes have different one-way transaction costs, with listed property and gold being substantially more expensive to trade than cash and bonds.

The strategy therefore does not immediately move from the existing portfolio to the full target allocation.

Instead, it gradually adjusts positions towards the target.

This creates a trade-off between:

responding to changing market conditions

and

avoiding unnecessary turnover and transaction costs.

## Data

The challenge provides historical asset and macroeconomic data from **January 2004 through December 2025.**

## The asset data includes:

daily dates;
asset codes;
total-return index levels;
daily total returns.

## The macroeconomic data includes:

USD/ZAR;
DXY;
VIX;
Brent;
US 2-year yield;
US 10-year yield;
South African 10-year yield;
JIBAR 3-month;
South African repo rate;
emerging-market equity data.

The strategy uses the data supplied by the challenge and does not require external market data or APIs.

## Avoiding Look-Ahead Bias

The challenge framework provides historical observations strictly before the allocation date.

The strategy therefore constructs its signals using the information available in the historical data passed to the allocation function.

No information about the return of the allocation day is used when determining that day's portfolio weights.

## Implementation

The solution is implemented in R.

The main function is:

generate_weights(hist, prev_weights, params)


The allocation process can be summarised as:

Historical information
        ↓
Macro trend signals
        ↓
Cross-asset momentum
        ↓
Short-term reversal
        ↓
Signal standardisation
        ↓
Composite signal
        ↓
Benchmark + active tilt
        ↓
Portfolio constraints
        ↓
Gradual trading adjustment
        ↓
Final portfolio weights

## Key Parameters
Parameter	Value	Purpose
Momentum lookback	60 days	Cross-asset momentum
Short-term lookback	5 days	Reversal adjustment
Macro fast window	20 days	Short-term macro trend
Macro slow window	100 days	Long-term macro trend
Macro weight	65%	Macro contribution
Reversal weight	35%	Reversal contribution
Tilt size	5%	Signal-to-position scaling
Trade speed	10%	Daily adjustment towards target

The model uses a relatively small parameter set to keep the approach interpretable and avoid unnecessary complexity.

## Repository Structure
Prescient-Coding-Challenge/
│
├── solution.R
└── README.md


The main strategy implementation is contained in solution.R.

## Key Takeaway

The central idea behind the strategy is that asset allocation should respond to changing market conditions rather than relying on a permanent portfolio tilt.

The model combines:

macro trends + relative momentum + short-term reversal + controlled portfolio adjustments

to dynamically position the portfolio around its benchmark while accounting for portfolio constraints and transaction costs.

## Disclaimer

This repository documents a quantitative portfolio-allocation exercise completed for the **Prescient Investment Management Coding Challenge 2026.**

It is an educational and research project and does not constitute investment advice or a recommendation to buy or sell any financial instrument


