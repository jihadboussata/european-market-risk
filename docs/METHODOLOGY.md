# Risk definitions and backtest design

## Signs, units and horizons

For each index separately, sort valid positive prices by date, reject duplicate dates and compute L[t] = -100 log(P[t]/P[t-1]). Values are percentage log-return losses. A negative observed L is a gain; risk thresholds are not forcibly clamped to zero. A 3% log-loss threshold corresponds to a simple-price decline of 1-exp(-0.03), not exactly 3%. The horizon is one observed trading interval, which may span a holiday/weekend.

Confidence c ∈ {0.95, 0.99}; tail probability is 1-c. This replaces the original negative-return-quantile convention with a consistent upper-loss-tail convention.

## Historical VaR and ES

VaR is quantile(L, c, type=1), the inverse empirical CDF. Sort losses descending: l[1] >= ... >= l[n]. Let m=n(1-c), k=floor(m) and f=m-k. ES is (sum(l[1:k]) + f*l[k+1])/m, omitting the fractional term if f=0. It is the exact upper-tail integral of the empirical quantile function. This avoids averaging all observations above a rounded quantile, which can use the wrong tail mass in the presence of ties or fractional order statistics.

## Parametric assumptions

Normal VaR = mu + sigma*z[c]; normal ES = mu + sigma*phi(z[c])/(1-c), with sample mean and sample standard deviation.

For Student-t degrees of freedom v=5, use scale `s=sigma*sqrt((v-2)/v)`, so the assumed variance matches the estimated variance. Write q for the Student-t quantile at confidence c. Then `VaR=mu+s*q` and `ES=mu+s*(v+q^2)/(v-1)*dt(q,df=v)/(1-c)`. v is fixed, not fitted. Matching variance can make a t(5) 95% quantile lower than a Gaussian quantile; a heavier far tail does not imply a larger quantile at every confidence level.

The Monte Carlo calculation draws 100,000 normal losses with seed 42, then applies the same empirical risk definitions. It approximates the analytic Gaussian model and is used as a numerical check, not an additional distributional hypothesis.

## Forward testing

For each observation after the first 252 returns, use exactly returns [t-252, t-1] to forecast VaR/ES at t. Compare observed L[t] with the forecast VaR using strict greater-than. Historical, Gaussian and t(5) models are all evaluated; no best model is selected using the test record. Full-sample estimates are labeled descriptive and are not used as forward forecasts.

Coverage records forecast count, breach count/rate, longest consecutive breach run and the iid-binomial reference p-value/interval. Serial dependence, volatility clustering and overlapping estimation windows limit the reference test; its p-value is not a complete model-validation verdict. Multiple series/confidence/model comparisons are unadjusted. Independence and conditional-coverage tests are not implemented.

Mean realized loss on breach and mean forecast ES on those dates are descriptive diagnostics. Comparing these means is not a valid formal ES backtest by itself. No claim of ES calibration follows from them.

## Data comparability and reproducibility

The requested range is 2015-01-01 inclusive to 2026-01-01 exclusive. Four Yahoo chart series are processed separately, retaining their own trading calendars. Adjusted close is selected only if usable values cover the valid-close dates; otherwise close is used and recorded. The downloader's UTC timestamp, exact URLs, response hashes and normalized CSV hash are in the manifest. Yahoo revisions can change a later rerun; preserving that CSV is necessary for bit-for-bit input reproduction.

Index methodologies, dividends, local currencies and calendars differ. The study compares observed marginal return series, not currency-hedged total returns. Data terms apply independently of the code license.

References: [R quantile documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html); Acerbi and Tasche, [On the coherence of expected shortfall](https://arxiv.org/abs/cond-mat/0104295), for the quantile-integral definition.
