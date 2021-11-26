library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)
library(reshape2)
library(forecast)
library(imputeTS)

reorder_cormat <- function(cormat){
  # Use correlation between variables as distance
  dd <- as.dist((1-cormat)/2)
  hc <- hclust(dd)
  cormat <-cormat[hc$order, hc$order]
}
cormat <- reorder_cormat(cormat)
melted_cormat <- melt(cormat)

deseason <- function(df,plotornot) {
  trend_ma = ma(as.ts(df$hits), order = 52, centre = T)
  detrend = df$hits / trend_ma
  m_seas = t(matrix(data = detrend[27:(27+3*52-1)], nrow = 52))
  seas_mean = colMeans(m_seas, na.rm = T)
  temp = rep(seas_mean,8)
  temp2 = ma(as.ts(temp), order = 4,centre = T)
  seas_rep = temp2[(52-27+1+1):((52-27+1+1)+length(df$hits)-1)]  
  deseas = df$hits / seas_rep
  if (plotornot) {
    plot(as.ts(df$hits))
    lines(trend_ma)
    plot(as.ts(seas_rep))
  }
  return(deseas)
}

df_gt = read.csv("data\\gtrend_data.csv")
df_gt$date <- as.Date(df_gt$date)
df_gt$hits<-as.numeric(df_gt$hits)

search_terms <- c("curbside","outdoor dining",
                  "library hours","bar","best masks",
                  "indoor playground","evite","flight")

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

ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) + 
  geom_tile(color = "white")+
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Pearson\nCorrelation")+
  theme_minimal()+ 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 12, hjust = 1))+
  coord_fixed()

st <- "US-NY"
term <- "outdoor dining"
df_sub = subset(df_gt, state==st & search_term==term)
deseas = deseason(df_sub,1)

plot(df_sub$date,df_sub$hits,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")),
     main="Baseline original\n(NY-\"outdoor dining\")")
plot(df_sub$date,deseas,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")),
     main="Baseline seasonality removed\n(NY-\"outdoor dining\")")
plot(df_sub$date,df_sub$hits,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-18")),
     main="Post-COVID original\n(NY-\"outdoor dining\")")
plot(df_sub$date,deseas,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-18")),
     main="Post-COVID seasonality removed\n(NY-\"outdoor dining\")" )




df_dining_CA = subset(df_gt, state=="US-CA" & 
                        search_term=="outdoor dining")
#df_dining_CA$hits <- na_ma(df_dining_CA$hits, k = 4)
trend_dining = ma(as.ts(df_dining_CA$hits), order = 52, centre = T)
plot(as.ts(df_dining_CA$hits))
lines(trend_dining)
detrend = df_dining_CA$hits / trend_dining
plot(df_dining_CA$date,detrend,type ="l", 
     xlim=c(as.Date("2017-11-18"),as.Date("2021-11-18")))
m_seas = t(matrix(data = detrend[27:(27+104-1)], nrow = 52))
seasonal_dining = colMeans(m_seas, na.rm = T)
plot(as.ts(seasonal_dining))
temp = rep(seasonal_dining,6)
seas_dining = temp[(52-27+1+1):((52-27+1+1)+length(df_dining_CA$hits)-1)]
deseas = df_dining_CA$hits / seas_dining
plot(df_dining_CA$date,deseas,type ="l",
     xlim=c(as.Date("2016-11-18"),as.Date("2020-02-01")))
plot(df_dining_CA$date,df_dining_CA$hits,type ="l",
     xlim=c(as.Date("2016-11-18"),as.Date("2020-02-01")))
plot(df_dining_CA$date,deseas,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-18")))
# Also consider decompose() and stl()

df_dining_NY = subset(df_gt, state=="US-NY" & 
                        search_term=="outdoor dining")
trend_dining = ma(as.ts(df_dining_NY$hits), order = 52, centre = T)
lines(trend_dining)
detrend = df_dining_NY$hits / trend_dining
m_seas = t(matrix(data = detrend[27:(27+104-1)], nrow = 52))
seasonal_dining = colMeans(m_seas, na.rm = T)
plot(as.ts(seasonal_dining))
temp = rep(seasonal_dining,6)
seas_dining2 = temp[(52-27+1+1):((52-27+1+1)+length(df_dining_NY$hits)-1)]
deseas = df_dining_NY$hits / seas_dining
plot(df_dining_NY$date,deseas,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-18")))
plot(df_dining_NY$date,df_dining_NY$hits,type ="l",
     xlim=c(as.Date("2020-03-20"),as.Date("2021-11-18")))
plot(df_dining_NY$date,df_dining_NY$hits,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")))
plot(df_dining_NY$date,deseas,type ="l",
     xlim=c(as.Date("2017-11-18"),as.Date("2020-02-01")))
