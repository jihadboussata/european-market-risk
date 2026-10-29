# All inputs and outputs are percentage log-return losses: L = -100*diff(log(P)).
validate_losses <- function(losses, confidence) {
  if (length(losses)<2 || any(!is.finite(losses))) stop("At least two finite losses are required.")
  if (length(confidence)!=1 || confidence<=0 || confidence>=1) stop("Confidence must lie strictly between 0 and 1.")
}

historical_risk <- function(losses, confidence) {
  validate_losses(losses,confidence)
  # VaR: inverse empirical CDF. ES: exact integral of its upper tail, including
  # a fractional observation when n*(1-confidence) is not an integer.
  ordered <- sort(losses,decreasing=TRUE)
  mass <- length(losses)*(1-confidence)
  whole <- floor(mass)
  fraction <- mass-whole
  total <- if(whole>0) sum(ordered[seq_len(whole)]) else 0
  if(fraction>0) total <- total + fraction*ordered[whole+1]
  c(var=unname(quantile(losses,confidence,type=1)),es=total/mass)
}

normal_risk <- function(losses, confidence) {
  validate_losses(losses,confidence)
  mu <- mean(losses); sigma <- sd(losses); z <- qnorm(confidence)
  c(var=mu+sigma*z,es=mu+sigma*dnorm(z)/(1-confidence))
}

student_risk <- function(losses,confidence,df=5) {
  validate_losses(losses,confidence)
  if(df<=2) stop("Finite-variance standardization requires df > 2.")
  mu <- mean(losses); scale <- sd(losses)*sqrt((df-2)/df); z <- qt(confidence,df=df)
  c(var=mu+scale*z,es=mu+scale*(df+z*z)/(df-1)*dt(z,df=df)/(1-confidence))
}

normal_monte_carlo <- function(losses,confidence,n=100000,seed=42) {
  validate_losses(losses,confidence)
  set.seed(seed)
  simulated <- rnorm(n,mean(losses),sd(losses))
  historical_risk(simulated,confidence)
}

prices_to_losses <- function(prices) {
  if(!all(c("date","index","close") %in% names(prices))) stop("Expected date,index,close columns.")
  prices$date <- as.Date(prices$date)
  if(anyNA(prices$date) || any(!is.finite(prices$close) | prices$close<=0)) stop("Invalid source prices.")
  if(anyDuplicated(prices[,c("index","date")])) stop("Duplicate index/date prices.")
  results <- lapply(split(prices,prices$index),function(d) {
    d <- d[order(d$date),]
    data.frame(date=d$date[-1],index=d$index[-1],loss=-100*diff(log(d$close)))
  })
  do.call(rbind,results)
}

rolling_forecasts <- function(d,window=252,confidences=c(.95,.99)) {
  if(window<20 || nrow(d)<=window) stop("Insufficient history for the requested window.")
  d <- d[order(d$date),]
  if(anyDuplicated(d$date)) stop("One series with unique dates is required.")
  models <- list(historical=historical_risk,normal=normal_risk,student_t5=student_risk)
  rows <- vector("list",(nrow(d)-window)*length(confidences)*length(models)); k <- 0L
  for(i in seq.int(window+1,nrow(d))) {
    history <- d$loss[seq.int(i-window,i-1)]
    for(confidence in confidences) for(name in names(models)) {
      value <- models[[name]](history,confidence)
      k <- k+1L
      rows[[k]] <- data.frame(date=d$date[i],index=d$index[i],model=name,confidence=confidence,
        var=value[["var"]],es=value[["es"]],observed_loss=d$loss[i],
        breach=d$loss[i]>value[["var"]],estimation_end=d$date[i-1])
    }
  }
  do.call(rbind,rows)
}

coverage_summary <- function(forecasts) {
  groups <- split(forecasts,list(forecasts$index,forecasts$model,forecasts$confidence),drop=TRUE)
  do.call(rbind,lapply(groups,function(d) {
    n <- nrow(d); hits <- sum(d$breach); nominal <- 1-d$confidence[1]
    reference <- binom.test(hits,n,p=nominal)
    runs <- rle(d$breach)
    data.frame(index=d$index[1],model=d$model[1],confidence=d$confidence[1],forecasts=n,
      breaches=hits,nominal_breach_rate=nominal,observed_breach_rate=hits/n,
      iid_binomial_p=reference$p.value,iid_binomial_ci_low=reference$conf.int[1],
      iid_binomial_ci_high=reference$conf.int[2],
      longest_breach_run=max(c(0,runs$lengths[runs$values])),
      mean_realized_loss_on_breach=if(hits) mean(d$observed_loss[d$breach]) else NA_real_,
      mean_forecast_es_on_breach=if(hits) mean(d$es[d$breach]) else NA_real_)
  }))
}
