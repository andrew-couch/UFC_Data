library(tidyverse)
library(tidyselect)
library(rvest)

message("Scraping Cards")
scrape_cards <- function(link){
  
  link %>% 
    read_html() %>% 
    html_nodes(".b-link_style_black") %>% 
    html_attr("href") %>% 
    tibble("cards" = .)
}
scrape_dates <- function(link){
  
  link %>% 
    read_html() %>% 
    html_nodes(".b-list__box-list-item:nth-child(1)") %>% 
    html_text() %>% 
    tibble("fight_date" = .) %>% 
    separate(fight_date, into = c("key", "value"), sep = ":") %>% 
    select(date = value) %>% 
    mutate(date = str_replace_all(date, "\n","")) %>% 
    mutate(date = str_trim(date))
  
}
scrape_fights <- function(link){
  
  link %>% 
    read_html() %>% 
    html_nodes("a") %>% 
    html_attr("href") %>% 
    tibble("fights" = .) %>% 
    filter(str_detect(fights, "fight-details"))
  
}
scrape_fight_summary_data <- function(link){
  
  link <- link %>% read_html()
  
  
  table_df <- link %>% html_nodes("table")
  
  
  summary_data <- table_df[1] %>% 
    html_table(trim = TRUE, fill = TRUE) %>% 
    do.call("rbind", .) %>% 
    as_tibble() %>% 
    rename("Fighter" = 1, "KD" = 2, "Sig_Strike" = 3, "Sig_Strike_Percent" = 4, "Total_Strikes" = 5, 
           "TD" = 6, "TD_Percent" = 7, "Sub_Attempts" = 8, "Pass" = 9, "Rev" = 10) %>% 
    gather() %>% 
    separate(value, into = c("fighter_1", "fighter_2"), sep = "  ", extra = "merge") %>% 
    mutate_all(~str_replace_all(.x, "\n", "")) %>% 
    mutate_all(str_trim) %>% 
    pivot_wider(names_from = key, values_from = c(fighter_1, fighter_2)) %>% 
    separate(fighter_1_Sig_Strike, into = c("fighter_1_Sig_Strike_Landed", "fighter_1_Sig_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    separate(fighter_2_Sig_Strike, into = c("fighter_2_Sig_Strike_Landed", "fighter_2_Sig_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    separate(fighter_1_Total_Strikes, into = c("fighter_1_Strike_Landed", "fighter_1_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_2_Total_Strikes, into = c("fighter_2_Strike_Landed", "fighter_2_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_1_TD, into = c("fighter_1_TD_Landed", "fighter_1_TD_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_2_TD, into = c("fighter_2_TD_Landed", "fighter_2_TD_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    mutate_at(vars(contains("Percent")), ~.01*str_replace(.x, "%", "") %>% as.numeric()) %>% 
    mutate_at(vars(-contains("Fighter", ignore.case = FALSE)), as.numeric) 
  
  
  fight_details <- link %>% 
    html_nodes(xpath = '//*[contains(concat( " ", @class, " " ), concat( " ", "b-fight-details__text", " " )) and (((count(preceding-sibling::*) + 1) = 1) and parent::*)]//i') %>% 
    html_text() %>% 
    as_tibble() %>% 
    mutate(value = str_replace_all(value, "\n", "")) %>% 
    mutate(value = str_trim(value, side = "both")) %>% 
    separate(value, into = c("feature", "value"), sep = ":", extra = "merge") %>% 
    mutate(value = str_trim(value)) %>% 
    replace_na(list(value = "")) %>% 
    group_by(feature) %>% 
    filter(value != "") %>% 
    ungroup() %>% 
    pivot_wider(names_from = feature, values_from = value) %>% 
    rename_all(.funs = ~str_replace(.x, "\\s|/", "_") %>% tolower()) %>% 
    cbind(
      link %>% 
        html_node(".b-fight-details__persons") %>% 
        html_text() %>% 
        str_extract("[:upper:]{1}") %>% 
        tibble("fighter_1_res" = .)) %>% 
    mutate(fighter_2_res = case_when(
      fighter_1_res == "L" ~ "W",
      fighter_1_res == "W" ~ "L",
      TRUE ~ "D"
    )) %>% 
    rename("round_finished" = "round") %>% 
    cbind(
      link %>%       
        html_nodes(".b-fight-details__fight-title") %>% 
        html_text() %>% 
        str_replace_all("\n", "") %>% 
        str_trim() %>% 
        tibble(weight_class = .))
  
  summary_data <- cbind(summary_data, fight_details)

  summary_data %>% as_tibble()
  
}
scrape_round_data <- function(link){
  
  link <- link %>% read_html()
  
  table_df <- link %>% html_nodes("table")
  
  
  round_data <- table_df[2] %>% 
    html_table(trim = TRUE, fill = TRUE) %>% 
    do.call("rbind", .) %>% 
    as_tibble(.name_repair = "unique") %>% 
    rename("Fighter" = 1, "KD" = 2, "Sig_Strike" = 3, "Sig_Strike_Percent" = 4, "Total_Strikes" = 5, 
           "TD" = 6, "TD_Percent" = 7, "Sub_Attempts" = 8, "Pass" = 9, "Rev" = 10) %>% 
    gather() %>% 
    separate(value, into = c("fighter_1", "fighter_2"), sep = "  ", extra = "merge") %>% 
    mutate_all(~str_replace_all(.x, "\n", " ")) %>% 
    mutate_all(str_trim) %>% 
    pivot_wider(names_from = key, values_from = c(fighter_1, fighter_2)) %>% 
    unnest() %>% 
    mutate(round = row_number()) %>% 
    separate(fighter_1_Sig_Strike, into = c("fighter_1_Sig_Strike_Landed", "fighter_1_Sig_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    separate(fighter_2_Sig_Strike, into = c("fighter_2_Sig_Strike_Landed", "fighter_2_Sig_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    separate(fighter_1_Total_Strikes, into = c("fighter_1_Strike_Landed", "fighter_1_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_2_Total_Strikes, into = c("fighter_2_Strike_Landed", "fighter_2_Strike_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_1_TD, into = c("fighter_1_TD_Landed", "fighter_1_TD_Attempts"), 
             sep = " of ", extra = "merge") %>%
    separate(fighter_2_TD, into = c("fighter_2_TD_Landed", "fighter_2_TD_Attempts"), 
             sep = " of ", extra = "merge") %>% 
    mutate_at(vars(contains("Percent")), ~.01*str_replace(.x, "%", "") %>% as.numeric()) %>% 
    mutate_at(vars(-contains("Fighter", ignore.case = FALSE)), as.numeric)
  
  fight_details <- link %>% 
    html_nodes(xpath = '//*[contains(concat( " ", @class, " " ), concat( " ", "b-fight-details__text", " " )) and (((count(preceding-sibling::*) + 1) = 1) and parent::*)]//i') %>% 
    html_text() %>% 
    as_tibble() %>% 
    mutate(value = str_replace_all(value, "\n", "")) %>% 
    mutate(value = str_trim(value, side = "both")) %>% 
    separate(value, into = c("feature", "value"), sep = ":", extra = "merge") %>% 
    mutate(value = str_trim(value)) %>% 
    replace_na(list(value = "")) %>% 
    group_by(feature) %>% 
    filter(value != "") %>% 
    ungroup() %>% 
    pivot_wider(names_from = feature, values_from = value) %>% 
    rename_all(.funs = ~str_replace(.x, "\\s|/", "_") %>% tolower()) %>% 
    cbind(
      link %>% 
        html_node(".b-fight-details__persons") %>% 
        html_text() %>% 
        str_extract("[:upper:]{1}") %>% 
        tibble("fighter_1_res" = .)) %>% 
    mutate(fighter_2_res = case_when(
      fighter_1_res == "L" ~ "W",
      fighter_1_res == "W" ~ "L",
      TRUE ~ "D"
    )) %>% 
    rename("round_finished" = "round") %>% 
    cbind(
      link %>%       
        html_nodes(".b-fight-details__fight-title") %>% 
        html_text() %>% 
        str_replace_all("\n", "") %>% 
        str_trim() %>% 
        tibble(weight_class = .))
  
  
  round_data <- cbind(round_data, fight_details)
  round_data %>% as_tibble()
  
}
scrape_moneyline <- function(fighter){
  tibble(fighter = !!fighter) %>% 
    mutate(query = str_squish(fighter) %>% str_replace_all(" ", "+"),
           link = paste0("https://www.bestfightodds.com/search?query=", query)) %>% 
    select(fighter, link) %>% 
    mutate(link = map(link, read_html),
           link = map(link, ~html_nodes(.x, "#page-content a")),
           hist = map(link, ~html_attr(.x, "href")),
           name = map(link, html_text)) %>% 
    unnest(c(hist, name)) %>% 
    filter(fighter == name) %>% 
    select(fighter, hist) %>% 
    mutate(hist = paste0("https://www.bestfightodds.com", hist),
           hist = map(hist, read_html),
           hist = map(hist, .f = function(link){
             link %>%
               html_element(".flex-section") %>% 
               html_element(".flex-content-wrap") %>% 
               html_element("#page-wrapper") %>% 
               html_element("#page-container") %>% 
               html_element("#team-stats-container") %>% 
               html_table() %>%
               select(1, 3) %>% 
               mutate(var = rep(c("Card", "fighter_a", "fighter_b"), times = n() / 3),
                      pk = rep(c(1, 0, 0), times = n() / 3),
                      pk = cumsum(pk),
                      value = if_else(var == "Card", Matchup, paste0(Matchup, "_", `Closing range`))) %>% 
               select(pk, var, value) %>% 
               pivot_wider(names_from = var, values_from = value) %>%
               separate(fighter_a, c("fighter_a", "fighter_a_odds"), sep = "\\_") %>% 
               separate(fighter_b, c("fighter_b", "fighter_b_odds"), sep = "\\_") %>% 
               select(-pk)
           })) 
}

# Data Scraping -----------------------------------------------------------
scraped_cards <- read_csv("Data/fight_data_raw.csv")

UFC <- tibble(UFC_Page = "http://ufcstats.com/statistics/events/completed?page=all") %>% 
  # Scrape Fight Card links
  mutate(cards = map(UFC_Page, scrape_cards)) %>% unnest(cards) %>% 
  # Remove cards that have already been scraped
  anti_join(scraped_cards %>% select(cards) %>% distinct(), by = "cards") 

if(nrow(UFC) != 0){
  UFC <- UFC %>% 
    # Scrape card dates
    mutate(dates =  map(cards, scrape_dates)) %>% unnest(dates) %>% 
    # Scrape Fights from every Fight Card
    mutate(fights = map(cards, scrape_fights)) %>% unnest(fights)
  
  UFC_Data <- UFC %>% mutate(fight_data = map(fights, safely(scrape_fight_summary_data)))
  
  df <- UFC_Data %>% 
    unnest(fight_data) %>% 
    filter(row_number() %% 2 != 0) %>% 
    unnest(fight_data) %>% 
    mutate(round_finished = as.numeric(round_finished)) %>% 
    distinct() %>% 
    bind_rows(scraped_cards %>% mutate(time = as.character(time))) 
  
  df %>% write_csv("Data/fight_data_raw.csv")
  
  
  # Data Cleaning -----------------------------------------------------------
  message("Cleaning Data")
  # Clean head-to-head data
  df <- df %>% 
    # Deselect fields that will not be used in the model
    select(-UFC_Page, -cards, -fights) %>% 
    # Convert field name to lower case
    rename_all(tolower) %>% 
    # Convert date
    mutate(date = as.Date(date, format = "%B %d, %Y")) %>% 
    arrange(desc(date)) %>% 
    # Convert fields to categorical variables
    mutate(fighter_1_fighter = as.factor(fighter_1_fighter),
           fighter_2_fighter = as.factor(fighter_2_fighter),
           method = as.factor(method),
           fighter_1_res = as.factor(fighter_1_res),
           fighter_2_res = as.factor(fighter_2_res),
           weight_class = as.factor(weight_class)) %>% 
    # Adjust percents 
    mutate(fighter_1_sig_strike_percent = fighter_1_sig_strike_landed / fighter_1_sig_strike_attempts,
           fighter_1_td_percent = fighter_1_td_landed / fighter_1_td_attempts,
           fighter_2_sig_strike_percent = fighter_2_sig_strike_landed / fighter_2_sig_strike_attempts,
           fighter_2_td_percent = fighter_2_td_landed / fighter_2_td_attempts) %>% 
    # If no attempts than percent will be 0 (may be adjusted to a not attempted variable)
    mutate_at(vars(contains("percent")), .funs = ~if_else(is.nan(.x) == TRUE, 0, .x)) %>% 
    # Convert rounds and round_finished
    mutate(time_format = str_extract(time_format, "\\d")) %>% 
    rename("rounds" = time_format) %>% 
    mutate(rounds  = as.factor(rounds),
           round_finished = as.factor(round_finished)) %>% 
    # Convert method
    separate(method, into = c("method"), sep = "-", extra = "drop") %>% 
    mutate(method = str_trim(method),
           method = as.factor(method)) %>% 
    # Convert weight_class
    mutate(gender = str_extract(weight_class, "Women")) %>% 
    mutate(gender = if_else(is.na(gender) == TRUE, "Men", gender)) %>% 
    mutate(weight_class = str_extract(weight_class, "\\w+weight")) %>% 
    mutate(weight_class = if_else(is.na(weight_class == TRUE), "Catchweight", weight_class)) %>% 
    unite("weight_class", c(gender, weight_class)) %>% 
    mutate(weight_class = as.factor(weight_class)) %>% 
    # Convert referee
    mutate(referee = if_else(is.na(referee) == TRUE, "Missing", referee)) %>% 
    mutate(referee = as.factor(referee)) %>% 
    # Convert rounds
    mutate(rounds = if_else(is.na(rounds) == TRUE, round_finished, rounds)) %>% 
    # Create a fight pk for future feature engineering 
    mutate(row_num = row_number()) %>% 
    arrange(desc(row_num)) %>% 
    mutate(fight_pk = row_number()) %>% 
    arrange(row_num) %>% 
    select(-row_num) 
  
  # Fighter 1 data 
  fighter_1 <- df %>% 
    select(-fighter_2_fighter, -referee, -fighter_2_res) %>% 
    rename_all(.funs = ~str_replace(.x, "fighter_1_", "")) %>% 
    # Create defensive metrics 
    mutate("sig_strikes_avoided" = fighter_2_sig_strike_attempts - fighter_2_sig_strike_landed,
           "tds_defended" = fighter_2_td_attempts - fighter_2_td_landed,
           "strikes_avoided" = fighter_2_strike_attempts - fighter_2_strike_landed) %>% 
    # Create damage metrics 
    rename("kds_received" = fighter_2_kd,
           "sig_strikes_received" = fighter_2_sig_strike_landed,
           "strikes_received" = fighter_2_strike_landed,
           "tds_received" = fighter_2_td_landed) %>% 
    mutate(strike_percent = strike_landed / strike_attempts,
           sig_reg_mixture = sig_strike_attempts / strike_attempts,
           sig_reg_percent = (sig_strike_landed + strike_landed) / (sig_strike_attempts + strike_attempts)) %>% 
    # Remove unnecessary columns
    select(-fighter_2_sig_strike_attempts, 
           -fighter_2_sig_strike_percent,
           -fighter_2_strike_attempts,
           -fighter_2_td_attempts,
           -fighter_2_td_percent,
           -fighter_2_sub_attempts,
           -fighter_2_pass,
           -fighter_2_rev) %>% 
    # Sort the columns
    select(sort(peek_vars())) 
  
  # Fighter 2 data
  fighter_2 <- df %>% 
    select(-fighter_1_fighter, -referee, -fighter_1_res) %>% 
    rename_all(.funs = ~str_replace(.x, "fighter_2_", "")) %>% 
    # Create defensive metrics 
    mutate("sig_strikes_avoided" = fighter_1_sig_strike_attempts - fighter_1_sig_strike_landed,
           "tds_defended" = fighter_1_td_attempts - fighter_1_td_landed,
           "strikes_avoided" = fighter_1_strike_attempts - fighter_1_strike_landed) %>% 
    # Create damage metrics 
    rename("kds_received" = fighter_1_kd,
           "sig_strikes_received" = fighter_1_sig_strike_landed,
           "strikes_received" = fighter_1_strike_landed,
           "tds_received" = fighter_1_td_landed) %>% 
    mutate(strike_percent = strike_landed / strike_attempts,
           sig_reg_mixture = sig_strike_attempts / strike_attempts,
           sig_reg_percent = (sig_strike_landed + strike_landed) / (sig_strike_attempts + strike_attempts)) %>% 
    # Remove unnecessary columns
    select(-fighter_1_sig_strike_attempts, 
           -fighter_1_sig_strike_percent,
           -fighter_1_strike_attempts,
           -fighter_1_td_attempts,
           -fighter_1_td_percent,
           -fighter_1_sub_attempts,
           -fighter_1_pass,
           -fighter_1_rev) %>% 
    # Sort the columns 
    select(sort(peek_vars()))
  
  # Combine fighter 1 and fighter 2 data 
  fight_data <- bind_rows(fighter_1, fighter_2) %>% arrange(desc(fight_pk))
  
  write_csv(fight_data,"Data/fight_data.csv")
  
  # moneyline_history <- read_csv("Data/moneyline.csv")
  # 
  # message("Scraping Moneylines")
  # moneyline_df <- fight_data %>% 
  #   slice_max(date) %>% 
  #   select(fighter) %>% 
  #   distinct(fighter) %>% 
  #   mutate(moneyline = map(fighter, safely(scrape_moneyline))) %>% 
  #   select(moneyline) %>% 
  #   mutate(moneyline = map(moneyline, ~pluck(.x, 1))) %>% 
  #   unnest(moneyline) %>% 
  #   unnest(hist) %>% 
  #   select(-fighter)
  # 
  # bind_rows(
  #   moneyline_history,
  #   moneyline_df,
  # ) %>% 
  #   distinct() %>%
  #   write_csv("Data/moneyline.csv")
} else {
  message("No new cards")
}

write_file(paste0("\n", Sys.time(), ": ", nrow(UFC), " fights scraped"), file = "logs.txt", append = TRUE)