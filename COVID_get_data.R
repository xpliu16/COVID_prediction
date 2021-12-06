library(gtrendsR)
search_terms <- c("curbside","outdoor dining",
                  "library hours","bar","best masks",
                  "indoor playground","evite","flight")

#states <- paste0("US-",state.abb)
#states <- states[-2]
states = c("US-CA","US-TX","US-FL","US-NY","US-PA")

temp1 <- array (dim = 11000)
temp2 <- array (dim = 11000)
temp3 <- array (dim = 11000)
temp4 <- array (dim = 11000)

ind<-1
for (words in search_terms) {
  for (s in states){
    print(paste(s,words))
    gtrends(keyword = c(words), 
            geo = c(s),
            time = "2016-12-6 2021-12-6") -> result1
    result <- result1$interest_over_time
    nrows = length(result$hits)
    temp1[ind:(ind+nrows-1)] <- paste0(as.Date(result$date))
    temp2[ind:(ind+nrows-1)] <- (result$hits)
    temp3[ind:(ind+nrows-1)] <- (replicate(nrows, words))
    temp4[ind:(ind+nrows-1)] <- (replicate(nrows, s))
    ind<-ind+nrows
    plot(result$date,result$hits,type="l",col="red")
  }
}

df <- data.frame(t(rbind(temp1,temp3,temp4,temp2)))
colnames(df) <- c("date","search_term","state","hits")

write.csv(df,"C:\\Users\\Ping\\Desktop\\Project\\COVID_prediction\\data\\gtrend_data.csv", row.names = FALSE)
# normalization