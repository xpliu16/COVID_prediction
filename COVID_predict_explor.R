library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)
library(reshape2)
library(forecast)
library(imputeTS)
library(FBN)
library(covidcast)
library(vars)
library(lubridate)
library(vars)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

reorder_cormat <- function(cormat){
  # Use correlation between variables as distance
  dd <- as.dist((1-cormat)/2)
  hc <- hclust(dd)
  cormat <-cormat[hc$order, hc$order]
}

deseason <- function(df,plotornot) {
  hits_no_na <- na_ma(df$hits, weighting = "simple")
  med_filt <- medianFilter(hits_no_na, 3)
  trend_ma = ma(as.ts(med_filt), order = 52, centre = T)
  detrend = med_filt / trend_ma
  m_seas = t(matrix(data = detrend[27:(27+2*52-1)], nrow = 52))
  seas_mean = colMeans(m_seas, na.rm = T)
  temp = rep(seas_mean,8)
  temp2 = ma(as.ts(temp), order = 4,centre = T)
  seas_rep = temp2[(52-27+1+1):((52-27+1+1)+length(df$hits)-1)]  
  deseas = med_filt / seas_rep
  if (plotornot) {
    plot(as.ts(df$hits))
    lines(trend_ma)
    plot(as.ts(seas_rep))
  }
  return(deseas)
  # Also consider decompose() and stl()
}

normalize <- function(x) {
  return ((x - min(x,na.rm=T)) / (max(x,na.rm=T) - min(x,na.rm=T)))
}
df_gt = read.csv("data\\gtrend_data.csv")
df_gt$date <- as.Date(df_gt$date)
df_gt$hits<-as.numeric(df_gt$hits)

search_terms <- c("curbside","outdoor dining",
                  "library hours","bar","best masks",
                  "indoor playground","evite","flight")

states = c("US-CA","US-TX","US-FL","US-NY","US-PA")

df_pre = filter(df_gt,date<as.Date("2020-02-01"))
df_post = filter(df_gt,date>as.Date("2020-03-20"))
# Second phase as mask wearing and social distancing begin to be encouraged
#df_post2 = filter(df_gt,date>as.Date("2020-05-20"))
print(paste("Length total:", dim(df_gt)[1]))
print(paste("Length pre-COVID:", dim(df_pre)[1]))
print(paste("Length post-COVID:", dim(df_post)[1]))

ggplot(filter(df_gt,state=="US-CA"), aes(x=date, y=hits)) +
  geom_line() + 
  xlab("Date")+
  facet_grid(search_term~.,
             labeller = label_wrap_gen(width = 2, multi_line = TRUE))
# Try for CA
df_post_CA = filter(df_post,state == "US-CA")
bar_CA = filter(df_post,state == "US-CA" & search_term == "bar")
curbside_CA = filter(df_post,state == "US-CA" & search_term == "curbside")

for (words in search_terms) {
  df_post_CA$hits[df_post_CA$search_term==words]<- 
    df_post_CA$hits[df_post_CA$search_term==words]/
    max(df_post_CA$hits[df_post_CA$search_term==words])*
    100
}

for (words in c("library hours","bar","indoor playground","evite","flight")) {
  # Terms showing decrease in caution
  df_post_CA$hits[df_post_CA$search_term==words]<- 
    -1*df_post_CA$hits[df_post_CA$search_term==words]
}
ggplot(df_post_CA, aes(x=date, y=hits, colour=search_term, group=search_term)) +
  geom_point(size=1) +
  geom_line(size=1) + 
  scale_y_continuous(limits = c(-100,100), breaks=seq(-100,100,25)) +
  ylab("Normalized hits") +
  scale_x_date(date_breaks = "3 months" , date_labels = "%b-%y")

# Second phase as mask wearing and social distancing begin to be encouraged
df_post2_CA = filter(df_gt,date>as.Date("2020-05-20")& state=="US-CA")
df_post2_CA = subset(df_post2_CA, select = -c(state))
df_post2_CA_wide <- spread(df_post2_CA, search_term, hits)
df_post2_CA_wide = subset(df_post2_CA_wide, select = -c(date))
cormat <-cor(df_post2_CA_wide)
cormat <- reorder_cormat(cormat)
melted_cormat <- melt(cormat)

ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) + 
  geom_tile(color = "white")+
  scale_fill_gradient2(low = "darkslategray", high = "coral", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Pearson\nCorrelation")+
  theme_minimal()+ 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 12, hjust = 1))+
  coord_fixed()

s <- "US-CA"
words <- "bar"
df_sub = subset(df_gt, state==s & search_term==words)
df_sub$hitsclean = tsclean(df_sub$hits, replace.missing = TRUE, lambda = NULL)
par(mfrow=c(2,2),
    oma = c(1,1,1,1),
    mar = c(3,2,3,1.5))
plot(df_sub$date,df_sub$hits,type="l",ylim=c(40,100),
     main="Original (\"bar\", CA)",font.main=1)
plot(df_sub$date,df_sub$hitsclean,type="l",ylim=c(40,100),
     main="After tsclean (\"bar\", CA)",font.main=1)
# tsclean got rid of outlier!

s <- "US-CA"
words <- "outdoor dining"
df_sub = subset(df_gt, state==s & search_term==words)
trend_ma = ma(as.ts(df_sub$hits), order = 52, centre = T)
plot(df_sub$date,as.ts(df_sub$hits),type="l",ylim=c(0,110),
     main="Original (\"outdoor dining\", CA)",font.main=1)
#lines(trend_ma)
cleaned = tsclean(df_sub$hits,replace.missing=TRUE, lambda = NULL)
trend_ma_cleaned = ma(as.ts(cleaned), order = 52, centre = T)
plot(df_sub$date,as.ts(cleaned),type="l",ylim=c(0,110),
     main="After tsclean (\"outdoor dining\", CA)",font.main=1)
#lines(trend_ma_cleaned)
# Did fix missing values, but not sure if outlier removal is too aggressive?

words <- "bar"
df_sub = subset(df_gt, state==s & search_term==words)
hits_no_na <- na_ma(df_sub$hits, weighting = "simple")
med_filt <- medianFilter(hits_no_na, 3)
plot(df_sub$date,as.ts(df_sub$hits),type="l",ylim=c(0,110),
     main="Original (\"bar\", CA)",font.main=1)
plot(df_sub$date,as.ts(med_filt),type="l",ylim=c(0,110),
     main="Median filtered (\"bar\", CA)",font.main=1)

words <- "outdoor dining"
df_sub = subset(df_gt, state==s & search_term==words)
hits_no_na <- na_ma(df_sub$hits, weighting = "simple")
med_filt <- medianFilter(hits_no_na, 3)
plot(df_sub$date,as.ts(df_sub$hits),type="l",ylim=c(0,110),
     main="Original (\"outdoor dining\", CA)",font.main=1)
plot(df_sub$date,as.ts(med_filt),type="l",ylim=c(0,110),
     main="Median filtered (\"outdoor dining\", CA)",font.main=1)

# Not as aggressive, still some peaks lopped off

s <- "US-PA"
words <- "bar"
df_sub = subset(df_gt, state==s & search_term==words)
hits_no_na <- na_ma(df_sub$hits, weighting = "simple")
med_filt <- medianFilter(hits_no_na, 3)
plot(as.ts(med_filt))
plot(as.ts(df_sub$hits))
# Don't like the look of it, but does suppress spikes

s <- "US-NY"
words <- "outdoor dining"
df_sub = subset(df_gt, state==s & search_term==words)
deseas = deseason(df_sub,1)
par(mfrow=c(2,2),
    oma = c(1,1,1,1),
    mar = c(3,2,3,1.5))
plot(df_sub$date,df_sub$hits,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")),
     main="Baseline original\n\"outdoor dining\"", 
     font.main=1,
     ylim=c(0,45),
     xlab="",
     ylab="")
plot(df_sub$date,deseas,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")),
     main="Baseline seasonality removed\n\"outdoor dining\"", 
     font.main=1,
     ylim=c(0,45),
     xlab="",
     ylab="")
plot(df_sub$date,df_sub$hits,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-28")),
     main="Post-COVID original\n\"outdoor dining\"",
     font.main=1,
     ylim=c(0,120),
     xlab="",
     ylab="")
plot(df_sub$date,deseas,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-28")),
     main="Post-COVID seasonality removed\n\"outdoor dining\"",
     font.main=1,
     ylim=c(0,120),
     xlab="",
     ylab="")
par(mfrow=c(1,1))

deseas_all = NULL
test_state = "US-NY"
states = c(test_state)
for (s in states){
  for (i in 1:length(search_terms)){
    df_sub = subset(df_gt, state==s & search_term==search_terms[i])
    deseas_all = append(deseas_all,deseason(df_sub,0))
  }
  deseas_mat <- matrix(deseas_all, ncol=length(search_terms),byrow=FALSE)
  deseas_scaled <- scale(deseas_mat, center = TRUE, scale = TRUE)
  terms.pca <- prcomp(deseas_scaled, center = FALSE, scale. = FALSE) # PCA
  summary(terms.pca)
}
caution = deseas_scaled %*% terms.pca$rotation[,1]
plot(df_sub$date,caution,type="l")
df_sub$caution_norm<-normalize(caution)

#plot(df_sub$date,df_sub$caution_norm,type="l",
#     xlim=as.Date(c("2020-05-01", "2021-11-28")),ylim=c(0,1),
#     lwd = 3, lty = 1, xlab="Date", ylab="Normalized value")
#axis.Date(1, at=seq(min(df_sub$date), max(df_sub$date), by="months"), format="%m-%Y")

data <- covidcast_signal("safegraph-weekly", "bars_visit_num",
                         start_day = "2020-05-01",
                         end_day = "2021-11-28",
                        "state")
# Warning: Data not fetched for the following days: 2020-12-14, 
# 2020-12-15, 2020-12-16, 2020-12-17, 2020-12-18, 2020-12-19, 2020-12-20 

data_sub <- subset(data, geo_value==tolower(substr(test_state,4,5)))
data_sub$value = na_ma(data_sub$value, weighting = "simple")
data_sub$value = ma(as.ts(data_sub$value),order =7,centre=T)
data_sub$value <- data_sub$value/max(data_sub$value,na.rm=T)*6
data_sub$value <- normalize(data_sub$value)

#lines(data_sub$time_value,normalize(data_sub$value),type="l",col="firebrick3",lwd=2)
#legend(x = "bottom",
       #       legend = c("Caution", "Restaurant visits"),
       #       lty = c(1,1),
       #       col = c("black","chocolate4"),
       #       lwd = 2,
       #       bty="n")

ggplot() +
  geom_line(data=df_sub,aes(x=date, y=caution_norm, color="Caution index"), 
            size=1) +
  geom_line(data=data_sub,aes(x=time_value,y=value,color="Bar visits"),
            size=1) +
  scale_y_continuous(limits = c(0,1), breaks=seq(0,1,0.5)) +
  ylab("Normalized value") +
  xlab("Date") +
  labs(color = "") +
  ggtitle(paste("Inferred caution vs. observed behavior\n (",s,")")) +
  theme(plot.title = element_text(hjust = 0.5)) +
  scale_x_date(limits = as.Date(c("2020-05-01","2021-11-28")),
               date_breaks = "3 months" , date_labels = "%b-%y") +
  theme(legend.position = c(1.1, 1),legend.justification = c(0, 1)) +
  theme(plot.margin = unit(c(0.5,4.5,0.5,0.5), "cm"))

data2 <- covidcast_signal("safegraph-weekly", "restaurants_visit_num",
                         start_day = "2020-05-01",
                         end_day = "2021-11-28",
                         "state")
data2_sub <- subset(data2, geo_value==tolower(substr(test_state,4,5)))
data2_sub$value <- na_ma(data2_sub$value, weighting = "simple")
data2_sub$value <- ma(as.ts(data2_sub$value),order =7,centre=T)
data2_sub$value <- data2_sub$value/max(data2_sub$value,na.rm=T)*6
data2_sub$value <- normalize(data2_sub$value)

ggplot() +
  geom_line(data=df_sub,aes(x=date, y=caution_norm, color="Caution index"), 
            size=1) +
  geom_line(data=data2_sub,aes(x=time_value,y=value,color="Restaurant visits"),
            size=1) +
  scale_y_continuous(limits = c(0,1), breaks=seq(0,1,0.5)) +
  ylab("Normalized value") +
  xlab("Date") +
  labs(color = "") +
  ggtitle(paste("Inferred caution vs. observed behavior\n (",s,")")) +
  theme(plot.title = element_text(hjust = 0.5)) +
  scale_x_date(limits = as.Date(c("2020-05-01","2021-11-28")),
               date_breaks = "3 months" , date_labels = "%b-%y") +
  theme(legend.position = c(1.1, 1),legend.justification = c(0, 1)) +
  theme(plot.margin = unit(c(0.5,4.5,0.5,0.5), "cm"))
  

# Mask data only available after 2021-02-09?
data3 <- covidcast_signal("fb-survey", "smoothed_wearing_mask_7d",
                          start_day = "2020-05-01",
                          end_day = "2021-11-28",
                          "state")
data3_sub <- subset(data3, geo_value==tolower(substr(test_state,4,5)))
data3_sub$value = na_ma(data3_sub$value, weighting = "simple")
data3_sub$value = ma(as.ts(data3_sub$value),order =7,centre=T)
data3_sub$value <- data3_sub$value/max(data3_sub$value,na.rm=T)*6
data3_sub$value <- normalize(data3_sub$value)

ggplot() +
  geom_line(data=df_sub,aes(x=date, y=caution_norm, color="Caution index"), 
            size=1) +
  geom_line(data=data3_sub,aes(x=time_value,y=value,color="Public masking"),
            size=1) +
  scale_y_continuous(limits = c(0,1), breaks=seq(0,1,0.5)) +
  ylab("Normalized value") +
  xlab("Date") +
  labs(color = "") +
  ggtitle(paste("Inferred caution vs. observed behavior\n (",s,")")) +
  theme(plot.title = element_text(hjust = 0.5)) +
  scale_x_date(limits = as.Date(c("2020-05-01","2021-11-28")),
               date_breaks = "3 months" , date_labels = "%b-%y") +
  theme(legend.position = c(1.1, 1),legend.justification = c(0, 1)) +
  theme(plot.margin = unit(c(0.5,4.5,0.5,0.5), "cm"))

df <- data.frame(df_sub$date, df_sub$caution_norm)
colnames(df) <- c("date","caution")
write.csv(df,"C:\\Users\\Ping\\Desktop\\Project\\COVID_prediction\\data\\gtrend_caution.csv", row.names = FALSE)

# Grab new cases
df_cv = read.csv("data\\United_States_COVID-19_Cases_and_Deaths_by_State_over_Time.csv")
#df_cv2 = read.csv("data\\data_table_for_daily_case_trends__the_united_states.csv")

df_ca = subset(df_cv, state=="CA")

temp <- strptime(df_ca$submission_date, "%m/%d/%Y")
df_ca$submission_date <- format(temp, "%Y-%m-%d")

df_ca$week <- floor_date(as.Date(df_ca$submission_date), "week")
df_cv_weekly <- df_ca %>%
  group_by(week) %>%
  summarize(mean = mean(new_case))
df_cv_weekly <- rename(df_cv_weekly, new_case = mean)
plot(df_cv_weekly$week, df_cv_weekly$new_case,type='l')
df_cv_weekly <- subset(df_cv_weekly, week>'2020-05-20')
df_cv_weekly$new_case<-normalize(df_cv_weekly$new_case)

df_sub<-subset(df_sub,date>'2020-05-20')
df_cv_weekly$caution <- df_sub$caution_norm

df_cv_weekly$log_caution = log(df_cv_weekly$caution+0.01)
df_cv_weekly$log_new_case = log(df_during$new_case+0.01)

x_train = cbind(df_cv_weekly$new_case[1:round(0.85*length(df_cv_weekly$new_case))], 
                df_sub$caution_norm[1:round(0.85*length(df_cv_weekly$new_case))])
colnames(x_train) <- c("log_new_case", "log_caution") 
fitvar1= VAR(x_train, p=5, type="both")
summary(fitvar1)


