install.packages("tidyverse")
suppressMessages(library("tidyverse"))
install.packages("viridis")
suppressMessages(library("viridis"))
install.packages("gridExtra")
suppressMessages(library("gridExtra"))
library("modelr")
install.packages("broom")
suppressMessages(library("broom"))
library("broom")
install.packages("ggrepel")
library("ggrepel")
set.seed(42)
install.packages("ggplot")
library("ggplot")
library("dplyr")

# All International Football Matches
# downloaded from kaggle: "https://www.kaggle.com/martj42/international-football-results-from-1872-to-2017/downloads/results.csv"
allmatches <- suppressMessages(read_csv("E:\\Project\\Last\\results.csv")) %>% mutate(Year=as.numeric(format(date,"%Y")))

# Matches of Fifa 2018
# Source: http://fixturedownload.com/download/fifa-world-cup-2018-RussianStandardTime.csv
fifa2018worldcup <- suppressMessages(read_csv("E:\\Project\\Last\\fifa-world-cup-2018.csv"))


# Prediction Dataset
# Step 1 Clean Data
fifa2018worldcup_pred <- fifa2018worldcup %>% 
  mutate(Date=as.Date(Date,"%d/%m/%Y %H:%M"),
  ) %>% 
  select(Date,Round='Round Number',Group,home_team='Home Team',away_team='Away Team') %>%
  mutate(home_team=ifelse(str_detect(home_team,"Group"),ifelse(str_detect(home_team,"Winner"),
                                                               paste0(str_replace(home_team,"Winner Group",""),"1"),
                                                               paste0(str_replace(home_team,"Runner-up Group",""),"2")),home_team),
         away_team=ifelse(str_detect(away_team,"Group"),ifelse(str_detect(away_team,"Winner"),
                                                               paste0(str_replace(away_team,"Winner Group",""),"1"),
                                                               paste0(str_replace(away_team,"Runner-up Group",""),"2")),away_team),
         Round=ifelse(Round %in% c("1","2","3"),paste0("G"),Round),
         Round=ifelse(Round == "Round of 16","LS",Round),
         Round=ifelse(Round == "Quarter Finals","QF",Round),
         Round=ifelse(Round == "Semi Finals","SF",Round),
         Round=ifelse(Round == "Finals","F",Round)) %>% group_by(Round) %>% 
  mutate(GameID=paste0(Round,1:n()),
         Winner=paste0("Winner_",GameID),
         Looser=paste0("Looser_",GameID),
         Group=ifelse(is.na(Group),"All",Group),
         home_team=ifelse(Group=="All",str_replace_all(home_team,"[\t\b ]",""),home_team),
         away_team=ifelse(Group=="All",str_replace_all(away_team,"[\t\b ]",""),away_team)) %>% ungroup() 

fifa2018worldcup_pred <- rbind(fifa2018worldcup_pred %>% filter((Round %in% c("G","LS"))),fifa2018worldcup_pred %>% filter(!(Round %in% c("G","LS"))) %>%
                                 mutate(home_team=c(paste0("LS",c(1,5,7,3)),paste0("QF",c(1,3)),"SF1","SF1"),
                                        away_team=c(paste0("LS",c(2,6,8,4)),paste0("QF",c(2,4)),"SF2","SF2")))

# Create List of Teams in Tournament
fifa2018teams <- fifa2018worldcup_pred %>% filter(Round=="G") %>% count(home_team) %>% select(home_team)
fifa2018teams <- fifa2018teams$home_team


head(allmatches)
tail(allmatches)
cbind(c("Games","Variables"),dim(allmatches))

options(repr.plot.width=7, repr.plot.height=4)
top_7_tournaments <- allmatches %>% count(tournament) %>% top_n(7,n) %>% select(-n) 
top_7_tournaments <- allmatches %>% filter(tournament!="Friendly") %>% ungroup() %>% 
  mutate(Year=floor(Year/4)*4,
         tournament=ifelse(tournament %in% top_7_tournaments$tournament,tournament,"Other")) %>%
  group_by(tournament)

ggplot(top_7_tournaments %>% count(Year) %>% filter(!is.na(Year) & !is.na(n) & Year<2016) ,
       aes(x=Year,y=n,fill=reorder(tournament,n,sum))) + 
  geom_area(show.legend=T, color="White",size=0.5) + scale_fill_viridis(discrete=T) + 
  scale_x_continuous(limits=c(min(top_7_tournaments$Year),max(top_7_tournaments$Year)-1))+
  labs(y="") + ggtitle("Annual matches") + theme_minimal()

ggplot(top_7_tournaments%>% filter(!is.na(tournament))  %>% count(tournament)  , 
       aes(x=reorder(tournament,n,sum), y=n, fill=n)) + labs(y="", x="", fill="") +
  geom_bar(stat="identity", pos="stack",show.legend=F) + coord_flip() + 
  scale_fill_viridis() + ggtitle("Occasions")+ theme_minimal()

# Recode Matches
matches <- allmatches %>% mutate(Importance = ifelse(str_detect(tournament,"FIFA"),1,NA),
                                 Importance = ifelse(str_detect(tournament,"UEFA"),.9,Importance),
                                 Importance = ifelse(str_detect(tournament,"Copa Am�rica"),.5,Importance),
                                 Importance = ifelse(str_detect(tournament,"African Cup of Nations"),.5,Importance),
                                 Importance = ifelse(!str_detect(tournament,"Friendly") & is.na(Importance),.1,Importance),
                                 Importance = ifelse(str_detect(tournament,"Friendly"),.01,Importance),
                                 Importance = ifelse(str_detect(tournament,"qualification"),Importance*.75,Importance))

top5competitions <- suppressMessages(matches %>% group_by(tournament) %>% summarise(n=n(),Importance=mean(Importance)) %>% arrange(-Importance) %>% top_n(5))

options(repr.plot.width=8, repr.plot.height=4)
ggplot(top5competitions,aes(x=n,y=Importance,colour=tournament,size=n))+
  geom_point()+  ggtitle("Importance by Tournament")+ theme_minimal() + scale_colour_viridis(discrete=T) +
  guides(size=FALSE) + theme(legend.position="bottom")+labs(y="",colour="",x="\nNumber of Games 1872-2018")


options(repr.plot.width=4, repr.plot.height=3)
fifa_finals <- matches %>% filter(str_detect(tournament,"FIFA") &  !str_detect(tournament,"qualification")) %>%  
  mutate(doy=as.numeric(format(date,"%j"))) %>% group_by(Year) %>% arrange(-Year,-doy) %>% filter(doy==max(doy)) %>%
  mutate(Winner=ifelse(home_score>away_score,home_team,away_team),
         Looser=ifelse(home_score<away_score,home_team,away_team)) %>% ungroup() %>% select(Year,date,Winner,Looser,city)
options(repr.plot.width=6, repr.plot.height=3)

ggplot(fifa_finals %>% count(Winner), aes(x=reorder(Winner,n,sum),y=n,fill=reorder(Winner,n,sum))) + 
  geom_bar(stat="identity", show.legend=F) + scale_fill_viridis(discrete=T) + 
  labs(x="", y="") + ggtitle("FIFA World Cup Winners") + theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust=1))
ggplot(fifa_finals %>% count(Looser), aes(x=reorder(Looser,n,sum),y=n,fill=reorder(Looser,n,sum))) + 
  geom_bar(stat="identity", show.legend=F) + scale_fill_viridis(discrete=T) + 
  labs(x="", y="") + ggtitle("FIFA World Cup Loosers") + theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust=1))


teams <- rbind(matches %>% select(Year,date,Team=home_team, Opponent = away_team,
                                  scored=home_score,received=away_score,Importance) 
               %>% mutate(Location="Home"),
               matches %>% select(Year,date,Team=away_team, Opponent = home_team,
                                  scored=away_score,received=home_score,Importance) %>% 
                 mutate(Location="Away")) %>%
  arrange(date) %>% 
  group_by(Year,Team) 
head(teams)
rbind(c("Matches","Features"),dim(teams))

team_strength_Year10 <- teams %>% 
  summarise(Won=mean(as.numeric(scored>received)), Matches=n(),
            Importance=sum(Importance)) %>% ungroup() %>% mutate(Year10=floor(Year/10)*10) %>% 
  group_by(Year10,Team) %>% 
  summarise(Won=mean(Won), Matches=sum(Matches),Importance=sum(Importance)) %>% 
  mutate(Strength=Won*Importance) %>%  arrange(-Year10,-Strength) %>% group_by(Year10) %>% 
  mutate(Strength=Strength/max(Strength))
#team_strength_Year10 %>% group_by(Team) %>% summarise(Strength=mean(Strength)) %>% arrange(-Strength) %>% top_n(5,Strength) %>% rename("Crude Strength (all years)"=Strength)



# Join Matches and Crude Opponent Strength Estimates 
basedata <- left_join(teams %>% mutate(Year10=floor(Year/10)*10),
                      team_strength_Year10 %>% ungroup() %>% select(Opponent=Team, Year10,Crude_Opp_Strength=Strength),
                      by=c("Opponent","Year10"), all.x=T) %>% filter(Year>=1955)

# Add features to control for
basedata <- basedata %>% mutate(Month=format(date, "%b"),Month_num=format(date, "%m"))

# Include Time to next final in yrs and indicator for Game Won
regdata <- left_join(basedata,fifa_finals %>% select(Year,Next_final=date),by="Year")  %>% 
  ungroup() %>% arrange(date)  %>% fill(Next_final, .direction="up") %>% filter(Year>=1955) %>% 
  mutate(Years_to_next_final=as.numeric(Next_final-date)/365) %>% select(-Year10,-Month,-Next_final) %>% 
  mutate(Game_Won=as.numeric(scored>received ))

# Filter: Predict only for Teams that managed to ever participate in FIFA Finals
legitteams <- regdata %>% filter(Importance==1 | Team %in% fifa2018teams) %>% count(Team) %>% filter(n>0)

# Function to recode features in Training and Prediction Datasets
mytransformations <- function(data) {
  data %>%
    mutate(Year2=Year^2,
           Year3=Year^3,
           Home=as.numeric(Location=="Home"))
}

# Create Training and Prediction Datasets
prediction.df <- regdata %>% filter(Year>1955 & Team %in% legitteams$Team) %>% 
  group_by(Team) %>%
  mytransformations(.)
margins.df <- data_grid(regdata %>% filter(Year>1955 & Team %in% legitteams$Team)  , 
                        Team= Team, Year = seq_range(Year,100),
                        Crude_Opp_Strength=1,Importance=1,Location="Home") %>% 
  mytransformations(.)

# Check Data Structures (uncomment only if necessary)
#prediction.df %>% ungroup() %>% count(Game_Won)
#head(prediction.df)
#head(margins.df)

# Fit Models
options(warn=-1)
prediction.model <- NULL
prediction.model <- prediction.df %>% 
  do(overall = glm(Game_Won ~ Crude_Opp_Strength+Importance+Year+Year^2+Year^3+Home+1,
                   family=binomial(link='logit'),data = ., weight=1/(1+2018-Year)),
     offensive = glm(scored ~ Crude_Opp_Strength+Importance+Year+Year^2+Year^3+Home+1,
                     family="poisson",data = ., weight=1/(1+2018-Year)),
     defensive = glm(received ~ Crude_Opp_Strength+Importance+Year+Year^2+Year^3+Home+1,
                     family="poisson",data = ., weight=1/(1+2018-Year)))
options(warn=0)
# Show Models (uncomment if necessary)
#head(tidy(prediction.model,fit))
#head(glance(prediction.model,fit))
#head(augment(prediction.model,overall,type.predict = "response"))
#head(augment(prediction.model,offensive,type.predict = "response"))
#head(augment(prediction.model,defensive,type.predict = "response"))


# Apply Model to Data
######################
# Check Dimensions
#length(prediction.model$fit)
#length(split(margins.df,margins.df$Team))

# Note: It is a crucial step to split margins.df by group Variable in prediction.df
overall.result <- map2_df(prediction.model$overall, split(margins.df,margins.df$Team), 
                          ~augment(.x, newdata = .y,type.predict = "response")) %>%
  mutate(fitted=round(.fitted,digits=4),
         min95=round(.fitted+qnorm(.025)*.se.fit,digits=4),
         max95=round(.fitted+qnorm(.975)*.se.fit,digits=4)) %>%
  select(Team,Year,Overall=fitted,Overall_min95=min95,Overall_max95=max95)

offensive.result <- map2_df(prediction.model$offensive, split(margins.df,margins.df$Team), 
                            ~augment(.x, newdata = .y,type.predict = "response")) %>%
  mutate(fitted=round(.fitted,digits=4),
         min95=round(.fitted+qnorm(.025)*.se.fit,digits=4),
         max95=round(.fitted+qnorm(.975)*.se.fit,digits=4)) %>%
  select(Team,Year,Offensive=fitted,Offensive_min95=min95,Offensive_max95=max95)

defensive.result <- map2_df(prediction.model$defensive, split(margins.df,margins.df$Team), 
                            ~augment(.x, newdata = .y,type.predict = "response")) %>%
  mutate(fitted=round(.fitted,digits=4),
         min95=round(.fitted+qnorm(.025)*.se.fit,digits=4),
         max95=round(.fitted+qnorm(.975)*.se.fit,digits=4)) %>%
  select(Team,Year,Defensive=fitted,Defensive_min95=min95,Defensive_max95=max95)

# Bind and recode
prediction.result <- cbind(overall.result,
                           offensive.result %>% select(-Team,-Year),
                           defensive.result %>% select(-Team,-Year)) %>%
  gather(Key,Value,3:11) %>%
  mutate(Area=str_split(Key,"_",simplify = TRUE)[,1],
         Statistic=str_split(Key,"_",simplify = TRUE)[,2],
         Statistic=ifelse(Statistic=="","est",Statistic)) %>% 
  select(-Key) %>% group_by(Area,Area,Statistic,Year) %>% 
  arrange(Area,Area,Statistic,-Year,Team) %>% 
  mutate(Value=ifelse(Area=="Defensive",1/(1+Value),Value),
         Value=50+20*scale(Value,center=T,scale=T))

# Define Function to join generated Strength to Matches
strengthjoin <- function(data){
  data %>% 
    left_join(.,final_strength_data %>% filter(Year==2018) %>% select(-Year) %>% 
                rename(home_team=Team,home_overall=Overall,
                       home_defensive=Defensive,home_offensive=Offensive), 
              by=c("home_team")) %>%
    left_join(.,final_strength_data %>% filter(Year==2018) %>% select(-Year) %>%
                rename(away_team=Team,away_overall=Overall,
                       away_defensive=Defensive,away_offensive=Offensive), 
              by=c("away_team"))
}
  
  #Defensive, Offensive, Overall
  options(repr.plot.width=8, repr.plot.height=5)
  fifa_winners <- fifa_finals %>% count(Winner)
  fifa_winners <- fifa_winners$Winner
  prediction.result %>% filter(Statistic=="est")  %>% 
    group_by(Team,Area) %>% select(-Statistic)  %>% top_n(1,Year) %>% 
    filter(Team %in% fifa2018teams) %>% ungroup() %>%
    mutate(Winner=ifelse(Team %in% fifa_winners,"Former Champion","Never Won")) %>%
    arrange(Area,-Value) %>%
    ggplot(.,aes(x=reorder(Team,Value),y=Value,fill=Winner)) + 
    facet_grid(~Area) + geom_bar(stat="identity") + coord_flip() + 
    labs(x="",title="Fifa 2018 World Cup Teams",fill="",y="Strength") +
    scale_fill_viridis(discrete=T) + guides(alpha=NULL) + theme_minimal() + theme(legend.position="bottom")
  
  
  # Final Stregth Data 
  final_strength_data <- prediction.result %>% filter(Statistic=="est") %>% ungroup() %>% 
    select(-Statistic) %>% 
    mutate(Year=round(Year)) %>% group_by(Team,Area,Year) %>% summarise(Value=mean(Value)) %>%
    ungroup() %>% spread(Area,Value)
  
  # Matches for Prediction
  train_database <- matches %>% filter(Year>1955 & Importance>=.8) 
  train_database <- left_join(train_database,final_strength_data %>% 
                                rename(home_team=Team,home_overall=Overall,
                                       home_defensive=Defensive,home_offensive=Offensive), 
                              by=c("home_team","Year")) %>%
    left_join(.,final_strength_data %>% 
                rename(away_team=Team,away_overall=Overall,
                       away_defensive=Defensive,away_offensive=Offensive), 
              by=c("away_team","Year"))  %>% rename(Date=date) %>%
    mutate(metricdate=as.numeric(format(as.Date(Date),"%Y"))+
             as.numeric(format(as.Date(Date),"%j"))/366) %>%
    select(-city,-country,-neutral,-Date)
  
  
  home_score_model <- train_database %>% glm(home_score ~ metricdate
                                             + I(metricdate*metricdate)
                                             + I(metricdate*metricdate*metricdate)
                                             + home_defensive
                                             + home_offensive
                                             + home_overall 
                                             + away_defensive 
                                             + away_offensive 
                                             + away_overall
                                             + 1 , data=., family="poisson")
  
  away_score_model <- train_database %>% glm(away_score ~ metricdate
                                             + I(metricdate*metricdate)
                                             + I(metricdate*metricdate*metricdate)
                                             + home_defensive
                                             + home_offensive
                                             + home_overall 
                                             + away_defensive 
                                             + away_offensive 
                                             + away_overall
                                             + 1 , data=., family="poisson")
  
  prob_model <- train_database %>% glm(home_score>away_score ~ metricdate
                                       + I(metricdate*metricdate)
                                       + I(metricdate*metricdate*metricdate)
                                       + home_defensive
                                       + home_offensive
                                       + home_overall 
                                       + away_defensive 
                                       + away_offensive 
                                       + away_overall
                                       + 1 , data=., family=binomial(link='logit'))
  
  # Function to predict Results based on Models
  predictresults <- function(data) {
    rawdata <- data
    data <- data %>% mutate(metricdate=as.numeric(format(as.Date(Date),"%Y"))+
                              as.numeric(format(as.Date(Date),"%j"))/366)
    cbind(rawdata,    
          cbind(
            augment(home_score_model,newdata=data,type.predict = "response") %>% 
              select(home_goals=.fitted),
            augment(away_score_model,newdata=data,type.predict = "response") %>% 
              select(away_goals=.fitted), 
            augment(prob_model,newdata=data,
                    type.predict = "response") %>% mutate(Probability=.fitted*100) %>% 
              select(home_prob=Probability) %>% ungroup() %>%
              mutate(away_prob=100-home_prob))) %>%
      mutate(Winner=ifelse(home_prob>=50,home_team,away_team),
             Looser=ifelse(home_prob<50,home_team,away_team))
  }
  
  # Predict Results
  results.groupphase <- fifa2018worldcup_pred %>% filter(Round =="G") %>% 
    strengthjoin(.) %>% ungroup() %>% 
    predictresults(.)
  # Show first 5 Matches
  head(results.groupphase %>% select(Date,Round,Group,home_team,away_team,GameID,contains("goals")) %>%
         mutate(home_goals=round(home_goals),
                away_goals=round(away_goals)))
  
  # Construct Tables
  group_tables <- rbind(
    results.groupphase %>% 
      select(Group,Round,Team=home_team,Scored=home_goals,
             Received=away_goals,Prob=home_prob),
    results.groupphase %>%  
      select(Group,Round,Team=away_team,Scored=away_goals,
             Received=home_goals,Prob=away_prob)
  ) %>% 
    mutate(
      Scored=round(Scored),
      Received=round(Received),
      Prob=round(Prob,digits=1),
      Pts = ifelse(Scored>Received,3,1),
      Pts = ifelse(Scored<Received,0,Pts)) %>%
    group_by(Group,Team) %>% 
    summarise(Goals=sum(Scored-Received),
              Pts=sum(Pts),
              Prob=mean(Prob)) %>% 
    arrange(Group,-Pts,-Goals) %>% 
    mutate(Round="Groupstage",
           Rank=1:n(),
           Label=paste0(str_split(Group," ",simplify=T)[,2],Rank))
  
  # Filter Winners
  winners_groupstage<-group_tables %>% filter(Rank<3) %>% ungroup() %>% select(Team,Label)
  
  #winners_groupstage
  options(repr.plot.width=6, repr.plot.height=3)
  plot.grouptables <-group_tables %>% mutate(Prob = round(Prob)) %>% select(Group,Rank,Team,Pts,Goals) %>%
    ggplot(.,aes(x=Group,label=Team,y=Rank,colour=Pts)) + geom_text(size=4) + guides(colour=F) +
    theme_minimal() + scale_color_viridis() + scale_y_continuous(limits=c(0.75,4.25),breaks=seq(1,4,1)) + 
    labs(y="Rank",x="",title="Group Table") + coord_flip()
  
  # Show Result
  options(repr.plot.width=6, repr.plot.height=4)
  plot.grouppoints<-group_tables %>% mutate(Prob = round(Prob)) %>% select(Group,Rank,Team,Pts,Goals) %>%
    ggplot(.,aes(x=Group,label=Team,y=Pts,colour=Pts)) + geom_text_repel(size=3.5) + 
    geom_point() + guides(colour=F) + theme_minimal() + scale_color_viridis() + 
    scale_y_continuous(limits=c(0,9),breaks=seq(0,10,2)) + labs(y="",x="",title="Points")
  plot.grouptables
  plot.grouppoints
  
  # Function to join winners of former round to Schedule in Knockoutphase
  joinwinners <- function(target,source) {target %>% 
      left_join(.,source %>% rename(home_team=Label),by=c("home_team")) %>% 
      mutate(home_team=Team) %>% select(-Team) %>%
      left_join(.,source %>% rename(away_team=Label),by=c("away_team"))  %>%
      mutate(away_team=Team) %>% select(-Team)
  }
  # Last 16
  results.last16 <- fifa2018worldcup_pred %>% filter(Round == "LS") %>% 
    joinwinners(.,winners_groupstage) %>%
    strengthjoin(.) %>%
    predictresults(.)
  head(results.last16 %>% select(Date,Round,Group,home_team,away_team,GameID,Winner, contains("goals"),home_prob) %>%
         mutate(home_goals=round(home_goals),
                away_goals=round(away_goals)))
  #results.last16 %>% select(Date,home_team,away_team,Winner,home_goals,away_goals,home_prob) %>%
  #mutate(home_goals=round(home_goals),away_goals=round(away_goals),home_prob=round(home_prob))
  
  # Quarter Finals
  results.last8 <- fifa2018worldcup_pred %>% filter(Round == "QF") %>% 
    joinwinners(.,results.last16 %>% select(Label=GameID,Team=Winner)) %>%
    strengthjoin(.) %>%
    predictresults(.)
  #results.last8 %>% select(Date,home_team,away_team,Winner,home_goals,away_goals,home_prob) %>%
  #mutate(home_goals=round(home_goals),away_goals=round(away_goals),home_prob=round(home_prob))
  
  # Semi Finals
  results.last4 <- fifa2018worldcup_pred %>% filter(Round == "SF") %>% 
    joinwinners(.,results.last8 %>% select(Label=GameID,Team=Winner)) %>%
    strengthjoin(.) %>%
    predictresults(.)
  #results.last4 %>% select(Date,home_team,away_team,Winner,home_goals,away_goals,home_prob) %>%
  #mutate(home_goals=round(home_goals),away_goals=round(away_goals),home_prob=round(home_prob))
  
  # Finals
  results.final <- rbind(fifa2018worldcup_pred %>% filter(Round == "F") %>% filter(GameID == "F1") %>% 
                           joinwinners(.,results.last4 %>% select(Label=GameID,Team=Looser)),
                         fifa2018worldcup_pred %>% filter(Round == "F") %>% filter(GameID == "F2") %>% 
                           joinwinners(.,results.last4 %>% select(Label=GameID,Team=Winner))) %>%
    strengthjoin(.) %>%
    predictresults(.)
  # results.final %>% select(Date,home_team,away_team,Winner,home_goals,away_goals,home_prob) %>%
  #mutate(home_goals=round(home_goals),away_goals=round(away_goals),home_prob=round(home_prob))
  #results.final %>% filter(GameID=="F2") %>% select("World Cup Winner"=Winner)
  #results.final %>% filter(GameID=="F2") %>% select("2nd Place"=Looser)
  #results.final %>% filter(GameID=="F1") %>% select("3nd Place"=Winner)
  
  Full_Tournament <- bind_rows(group_tables  %>% select(Round,Group,Team,Prob),
                               results.last16 %>% select(Round,Group=GameID,Team=home_team,Prob=home_prob),
                               results.last16 %>% select(Round,Group=GameID,Team=away_team,Prob=away_prob),
                               results.last8 %>% select(Round,Group=GameID,Team=home_team,Prob=home_prob),
                               results.last8 %>% select(Round,Group=GameID,Team=away_team,Prob=away_prob),
                               results.last4 %>% select(Round,Group=GameID,Team=home_team,Prob=home_prob),
                               results.last4 %>% select(Round,Group=GameID,Team=away_team,Prob=away_prob),
                               results.final %>% filter(GameID=="F2") %>% select(Round,Group=GameID,Team=home_team,Prob=home_prob),
                               results.final %>% filter(GameID=="F2") %>% select(Round,Group=GameID,Team=away_team,Prob=away_prob),
                               results.final %>% filter(GameID=="F2") %>% mutate(Round="Winner",Group="Winner",Team=Winner,Prob=100) %>%
                                 select(Round,Group,Team,Prob)) %>% ungroup() %>%
    mutate(Prob=round(Prob,digits=1),
           Round=ordered(Round, levels = c("Groupstage", "LS","QF","SF","F","Winner" ))) %>% group_by(Team) %>%
    arrange(Team,Round) %>% mutate(Source=lag(as.character(Round)),
                                   Target=lead(as.character(Round)),
                                   Source=ifelse(is.na(Source),"Qualification",Source),
                                   Target=ifelse(is.na(Target),"Dropout",Target),
                                   Target=ordered(Target,levels = c("Groupstage","Dropout", "LS","QF","SF","Winner")), 
                                   Source=ordered(Source,levels = c("Qualification","Groupstage", "LS","QF","SF","F","Winner"))
    )
  options(repr.plot.width=7, repr.plot.height=4,dpi=600)      
  plot.predictions<-ggplot(Full_Tournament, aes(y=as.character(Team),x=Round,group=Team,colour=Team,size=3)) + 
    geom_point() +geom_line(size=1.5)+guides(size=F,colour=F) +
    scale_color_viridis(discrete=T) + theme_minimal() +labs(y="",x="") +
    ggtitle("Fifa 2018 World Cup Predictions") + coord_flip() + 
    theme(axis.text.x = element_text(angle = 90, vjust =0.25,hjust=1))
  
  plot.predictions
  