#!/usr/bin/env Rscript
source("R/risk.R")
args <- commandArgs(trailingOnly=TRUE)
option <- function(key,default) { i <- match(key,args); if(is.na(i)) default else {
  if(i==length(args)) stop(paste("Missing value for",key)); args[i+1] } }
path <- option("--data","data/raw/index_prices.csv")
out <- option("--output","results")
window <- as.integer(option("--window","252"))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
prices <- read.csv(path,stringsAsFactors=FALSE)
losses <- prices_to_losses(prices)
series <- split(losses,losses$index)
summary_rows <- list(); coverage <- list(); k <- 0L
for(name in names(series)) {
  d <- series[[name]]
  for(confidence in c(.95,.99)) for(method in c("historical","normal","student_t5","normal_mc")) {
    fun <- switch(method,historical=historical_risk,normal=normal_risk,student_t5=student_risk,normal_mc=normal_monte_carlo)
    value <- fun(d$loss,confidence)
    k <- k+1L
    summary_rows[[k]] <- data.frame(index=name,confidence=confidence,method=method,n=nrow(d),
      first_return=as.character(min(d$date)),last_return=as.character(max(d$date)),
      mean_loss=mean(d$loss),sd_loss=sd(d$loss),var=value[["var"]],es=value[["es"]])
  }
  forecast <- rolling_forecasts(d,window)
  coverage[[name]] <- coverage_summary(forecast)
  # Forecast diagnostics are derived data; raw price series remain local.
  write.csv(forecast,file.path(out,paste0("rolling_",name,".csv")),row.names=FALSE)
}
summary <- do.call(rbind,summary_rows)
backtest <- do.call(rbind,coverage)
write.csv(summary,file.path(out,"risk_summary.csv"),row.names=FALSE)
write.csv(backtest,file.path(out,"coverage.csv"),row.names=FALSE)
png(file.path(out,"risk_comparison.png"),width=1700,height=850,res=160,type="cairo")
par(mfrow=c(1,2),mar=c(5,4,3,1))
for(confidence in c(.95,.99)) {
  d <- summary[summary$confidence==confidence & summary$method=="historical",]
  barplot(rbind(d$var,d$es),beside=TRUE,names.arg=d$index,col=c("#007f86","#ce6c31"),
    ylab="Daily log-return loss (%)",main=paste0(confidence*100,"% historical tail risk"),
    ylim=c(0,max(c(d$var,d$es))*1.35),
    legend.text=c("VaR","Expected shortfall"),args.legend=list(x="topleft",bty="n"))
}
dev.off()
png(file.path(out,"coverage.png"),width=1600,height=850,res=160,type="cairo")
par(mfrow=c(1,2),mar=c(5,4,3,1))
for(confidence in c(.95,.99)) {
  d <- backtest[backtest$confidence==confidence,]
  values <- tapply(d$observed_breach_rate,list(d$model,d$index),identity)
  barplot(values*100,beside=TRUE,col=c("#007f86","#ce6c31","#6776a9"),
    ylab="Observed VaR breach rate (%)",main=paste0(confidence*100,"% VaR: rolling ",window,"-day window"),
    ylim=c(0,max(values*100,100*(1-confidence))*1.3),
    legend.text=rownames(values),args.legend=list(x="topright",cex=.8,bty="n"))
  abline(h=100*(1-confidence),lty=2,col="gray30")
}
dev.off()
png(file.path(out,"loss_distributions.png"),width=1500,height=1100,res=160,type="cairo")
par(mfrow=c(2,2),mar=c(4,4,3,1))
for(name in names(series)) {
  x <- series[[name]]$loss
  hist(x,breaks=70,probability=TRUE,col="#007f86",border="white",xlab="Daily log-return loss (%)",main=name)
  curve(dnorm(x,mean(series[[name]]$loss),sd(series[[name]]$loss)),add=TRUE,col="#ce6c31",lwd=2)
}
dev.off()
manifest_path <- sub("\\.csv$",".manifest.json",path)
if(file.exists(manifest_path)) file.copy(manifest_path,file.path(out,"data_manifest.json"),overwrite=TRUE)
capture.output(sessionInfo(),file=file.path(out,"sessionInfo.txt"))
writeLines(c(paste("Input MD5:",unname(tools::md5sum(path))),paste("Window:",window),
  "Unit: one-day percentage log-return losses; seed 42; Monte Carlo draws 100000; fixed Student-t df 5."),file.path(out,"run_parameters.txt"))
print(summary[summary$method=="historical",]); print(backtest[,1:8])
