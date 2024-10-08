library(tidyverse)
library(rstatix)
library(ggpubr)
library(stringr)
library(caret)
# overview ---------------------------------------------------------------------
ZirFlu$HAItiter %>% count(season)
ZirFlu$HAItiter %>% filter(season == "2019") %>% count(condition)
ZirFlu$HAItiter %>% filter(season == "2020") %>% count(condition)

# NOTE:
# The participant Z-62 season 2019 were excluded because no serum samples were available.
# The participant Z-01-99-069 season 2020 has azathioprine in his medication 
# and were excluded from the analysis.

HAItiter <- list()
for (i in c("abFC", "T1", "T2", "T3")) {
  HAItiter[[i]] <- ZirFlu$HAItiter %>% select(patientID, season, condition,  matches(i)) %>%
    pivot_longer(!c("patientID", "season", "condition"), 
                 names_to = "strains", values_to = "log2_value") %>%
    mutate(condition = factor(condition, 
                              levels = c("healthy", "compensated cirrhosis", "decompensated cirrhosis"))) %>%
    mutate(disease = ifelse(condition == "healthy", "healthy", "cirrhosis")) %>%
    mutate(disease = factor(disease,
                            levels = c("healthy", "cirrhosis")))
}

# check if (de)compensated cirrhosis are not different --------------------------
## boxplot - HAI titer --------------------------------------------------------
datPlot <- HAItiter$abFC %>% filter(disease == "cirrhosis") %>% # HAI_abFC (T2 vs. T1)
  mutate(cirrhosis = gsub(' cirrhosis', '', condition))
datPlot <- HAItiter$T1 %>% filter(disease == "cirrhosis") %>% # HAI titer at T1
  mutate(cirrhosis = gsub(' cirrhosis', '', condition))
datPlot <- HAItiter$T2 %>% filter(disease == "cirrhosis") %>% # HAI titer at T2
  mutate(cirrhosis = gsub(' cirrhosis', '', condition))
datPlot <- HAItiter$T3 %>% filter(disease == "cirrhosis") %>% # HAI titer at T3
  mutate(cirrhosis = gsub(' cirrhosis', '', condition))

bxp <- datPlot %>%
  ggboxplot(x = "season", y = "log2_value", fill = "cirrhosis",
            bxp.errorbar = TRUE, palette = "npg",
            outlier.shape = 1, outlier.size = 4, outlier.color = "grey")

stat.test_condition <- datPlot %>% group_by(season) %>%
  t_test(log2_value ~ cirrhosis)%>% add_xy_position(x = "season", dodge = 0.8)

stat.test_condition_strain <- datPlot %>% group_by(season, strains) %>%
  t_test(log2_value ~ cirrhosis)%>% add_xy_position(x = "season", dodge = 0.8)

stat.test_2seasons <- datPlot %>%
  t_test(log2_value ~ cirrhosis)%>% add_xy_position(x = "season", dodge = 0.8)

stat.test_2seasons_strain <- datPlot %>% group_by(strains) %>%
  t_test(log2_value ~ cirrhosis)%>% add_xy_position(x = "season", dodge = 0.8)

bxp + 
  stat_pvalue_manual(
    stat.test_condition, label = "p", tip.length = 0.01, bracket.nudge.y = 1)  + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) + ylim(0, 15) + 
  ylab("log2(ab_FC)")
  #ylab("log2(HAI_T1)")
  #ylab("log2(HAI_T2)")
  #ylab("log2(HAI_T3)")
# meta-analysis -----------------
library(meta)
data("Fleiss1993cont")
head(Fleiss1993cont)
res <- metacont(n.psyc, mean.psyc, sd.psyc,
                n.cont, mean.cont, sd.cont,
                comb.fixed = T, comb.random = T, studlab = study,
                data = Fleiss1993cont, sm = "SMD")
forest(res, leftcols = c("studlab"))

library(dplyr)
datPlot <- HAItiter$abFC
datPlot2 <- datPlot %>% as_tibble() %>%
  group_by(season, condition, strains) %>% 
  summarise(count = n(), mean = mean(log2_value), sd = sd(log2_value))

datPlot3 <- datPlot2 %>% filter(condition != "healthy")

get.metaAnalysis_col <- function(dat, colnam) {
  outcome <- dat %>% select(c(1:3), all_of(colnam)) %>%
    pivot_wider(names_from = "condition", values_from = colnam) %>%
    rename_at(-c(1:2), ~paste0(colnam, ".", .x))
  return(outcome)
}

datPlot4 <- get.metaAnalysis_col(datPlot3, "count") %>%
  full_join(get.metaAnalysis_col(datPlot3, "mean")) %>%
  full_join(get.metaAnalysis_col(datPlot3, "sd")) %>%
  mutate(study = paste0(season, "_", strains))

colnames(datPlot4) <- substr(colnames(datPlot4), 1, 8)
datPlot5 <- datPlot4 %>% select(study, year, 
                                count.co, mean.com, sd.compe,
                                count.de, mean.dec, sd.decom)
res <- metacont(count.co, mean.com, sd.compe,
                count.de, mean.dec, sd.decom,
                comb.fixed = T, comb.random = T, studlab = study,
                data = datPlot4, sm = "SMD")

forest(res, leftcols = c("studlab"))

# make subgroup
library(metafor)
res1 <- metacont(count.co, mean.com, sd.compe,
                count.de, mean.dec, sd.decom,
                comb.fixed = T, comb.random = T, studlab = study, studgroup
                data = datPlot4, sm = "SMD")
ADGmetaHAKN_High_LS<-metacont(n.e = count.de,
                              mean.e = mean.dec,
                              sd.e = sd.decom, 
                              n.c = count.co,
                              mean.c = mean.com, 
                              sd.c = sd.compe, 
                              studlab = study,
                              data = datPlot4,
                              comb.fixed = FALSE,
                              comb.random = TRUE,
                              method.tau="REML",
                              hakn=TRUE,
                              byvar = datPlot4$season,
                              tau.common = FALSE)


forest(ADGmetaHAKN_High_LS,
       #sortvar = as.Date(subADG_High$Date),
       col.square = "green",
       col.square.lines = "green",
       col.diamond.random = "black",
       col.diamond.lines.random = "black",
       allstudies = TRUE,
       text.random = "Mean ADG",
       leftlabs=c("Study","N","Mean","SD","N","Mean","SD"),
       lab.e="decompensated",
       lab.c="compensated",
       comb.fixed=FALSE,
       comb.random = TRUE,
       label.left="Favours compensated", 
       col.label.left="red",
       label.right="Favours decompensated", 
       col.label.right="blue",
       hetstat=FALSE,
       test.overall.random = TRUE,
       digits.mean=2,
       digits.sd=2,
       digits.weight = 0,
       weight.study = "random",
       test.effect.subgroup.random = TRUE,
       overall = TRUE,
       print.byvar = FALSE,
       col.by="purple",
       addrow.subgroups=TRUE,
       addrow.overall=TRUE,
       addrow=TRUE,
       label.test.effect.subgroup.random="Subgroup effect",
       test.subgroup.random = TRUE)

datPlot <- get.metaAnalysis_col(datPlot3, "count") %>%
  full_join(get.metaAnalysis_col(datPlot3, "mean")) %>%
  full_join(get.metaAnalysis_col(datPlot3, "sd")) %>%
  mutate(study = paste0(season, "_", strains))

# specific strain case --------------
datPlot2 <- HAItiter$T2 %>% filter(disease == "cirrhosis") %>% 
  #filter(str_detect(strains, "Bvictoria"))
  filter(str_detect(strains, "Byamagata"))

datPlot2 <- HAItiter$T3 %>% filter(disease == "cirrhosis") %>% 
  #filter(str_detect(strains, "Bvictoria"))
  filter(str_detect(strains, "Byamagata"))

bxp2 <- datPlot2 %>%
  ggboxplot(x = "season", y = "log2_value", fill = "condition",
            bxp.errorbar = TRUE, palette = "npg",
            outlier.shape = 1, outlier.size = 4, outlier.color = "grey")

stat.test2 <- datPlot2 %>% group_by(season) %>%
  t_test(log2_value ~ condition)%>% add_xy_position(x = "season", dodge = 0.8)

bxp2 + 
  stat_pvalue_manual(
    stat.test2, label = "p", tip.length = 0.01, bracket.nudge.y = 1)  + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) + ylim(0, 15) + 
  #ylab("log2(HAI_T2_Bvictoria)")
  #ylab("log2(HAI_T2_Byamagata)")
  #ylab("log2(HAI_T3_Bvictoria)")
  ylab("log2(HAI_T3_Byamagata)")


# make PCA for protein and metabolite data -------------------------------------------
# HAI
metadata <- ZirFlu$HAItiter
metadata$condition <- factor(metadata$condition, 
                             levels = c("decompensated cirrhosis", 
                                        "compensated cirrhosis",  "healthy"))
HAItiter_raw <- ZirFlu$HAItiter %>% 
  select(-c(patientID, season, vaccine_response, category, condition))

HAItiter_impute <- predict(preProcess(x=HAItiter_raw, method = "knnImpute"), 
                           HAItiter_raw)
HAItiter_impute %>% 
  prcomp() %>% get.pca_plot(metadata, "condition")

# protein
metadata <- ZirFlu$donorSamples %>% full_join(ZirFlu$donorInfo) %>% 
  filter(patientID %in% ZirFlu$HAItiter$patientID) %>%
  filter(probenID %in% rownames(ZirFlu$protein_dat)) %>% 
  na.omit() %>% as.data.frame()
metadata$condition <- factor(metadata$condition, 
                             levels = c("decompensated cirrhosis", 
                                        "compensated cirrhosis",  "healthy"))
metadata$disease <- factor(metadata$disease, levels = c("cirrhosis", "healthy"))

protein_raw <- ZirFlu$protein_dat %>% 
  rownames_to_column(var = "probenID") %>% filter(probenID %in% metadata$probenID) %>%
  column_to_rownames("probenID")

protein_impute <- predict(preProcess(x=protein_raw, method = "knnImpute"), protein_raw)
protein_impute %>% 
  prcomp() %>% get.pca_plot(metadata, "condition")
protein_impute %>% 
  prcomp() %>% get.pca_plot(metadata, "disease")

# at T1 - baseline
metadata_T1 <- metadata %>% filter(time == "T1")
protein_impute_T1 <- protein_impute %>% 
  rownames_to_column(var = "probenID") %>% filter(probenID %in% metadata_T1$probenID) %>%
  column_to_rownames("probenID")
protein_impute_T1 %>% 
  prcomp() %>% get.pca_plot(metadata_T1, "disease")

# metabolite
metabolite_raw <- ZirFlu$metabolite_dat %>% 
  rownames_to_column(var = "probenID") %>% filter(probenID %in% metadata$probenID) %>%
  column_to_rownames("probenID")

metabolite_raw %>% 
  prcomp() %>% get.pca_plot(metadata, "condition")

metabolite_raw %>% 
  prcomp() %>% get.pca_plot(metadata, "disease")

# at T1 - baseline
metabolite_raw_T1 <- metabolite_raw %>% 
  rownames_to_column(var = "probenID") %>% filter(probenID %in% metadata_T1$probenID) %>%
  column_to_rownames("probenID")
metabolite_raw_T1 %>% 
  prcomp() %>% get.pca_plot(metadata_T1, "disease")

## per season ----------
metadata <- ZirFlu$HAItiter %>% 
  #filter(season == "2019")
  filter(season == "2020")
metadata$condition <- factor(metadata$condition, 
                             levels = c("healthy", "compensated cirrhosis", "decompensated cirrhosis"))

HAItiter_raw <- ZirFlu$HAItiter %>% 
  #filter(season == "2019") %>%
  filter(season == "2020") %>%
  select(-c(patientID, season, vaccine_response, category, condition))

HAItiter_impute <- predict(preProcess(x=HAItiter_raw, method = "knnImpute"), 
                           HAItiter_raw)
HAItiter_impute %>%
  prcomp() %>% get.pca_plot(metadata , "condition")

# protein
metadata <- ZirFlu$donorSamples %>% full_join(ZirFlu$donorInfo) %>% 
  filter(patientID %in% ZirFlu$HAItiter$patientID) %>%
  filter(probenID %in% rownames(ZirFlu$protein_dat)) %>% 
  na.omit() %>% as.data.frame() %>% 
  #filter(season == "2019")
  filter(season == "2020")
metadata$condition <- factor(metadata$condition, 
                             levels = c("healthy", "compensated cirrhosis", "decompensated cirrhosis"))

protein_raw <- ZirFlu$protein_dat %>% 
  rownames_to_column(var = "probenID") %>% filter(probenID %in% metadata$probenID) %>%
  column_to_rownames("probenID")

protein_impute <- predict(preProcess(x=protein_raw, method = "knnImpute"), protein_raw)
protein_impute %>% 
  prcomp() %>% get.pca_plot(metadata, "condition")

protein_impute %>% 
  prcomp() %>% get.pca_plot(metadata, "time")
# metabolite
metabolite_raw <- ZirFlu$metabolite_dat %>% 
  rownames_to_column(var = "probenIDs") %>% filter(probenID %in% metadata$probenID) %>%
  column_to_rownames("probenID")

metabolite_raw %>% 
  prcomp() %>% get.pca_plot(metadata, "condition")

metabolite_raw %>% 
  prcomp() %>% get.pca_plot(metadata, "time")
# the line of HAI change at T2 and T3 ------------------------
get.scatterPlot2(ZirFlu$HAItiter, "H1N1_T3", "H1N1_T2", "condition")

ZirFlu$HAItiter %>% 
  ggscatter(x = "H1N1_T2", y = "H1N1_T3", color = "condition", 
            add = "reg.line", palette = "jco") +
  stat_cor(aes(color = condition), method = "pearson")

ZirFlu$HAItiter %>% 
  ggscatter(x = "H1N1_T2", y = "H1N1_T3", color = "condition", add = "reg.line") +
  stat_cor(aes(color = condition), method = "pearson")

ZirFlu$HAItiter %>% 
  ggscatter(x = "H3N2_T2", y = "H3N2_T3", color = "condition", add = "reg.line") +
  stat_cor(aes(color = condition), method = "pearson")

ZirFlu$HAItiter %>% 
  ggscatter(x = "Bvictoria_T2", y = "Bvictoria_T3", color = "condition", add = "reg.line") +
  stat_cor(aes(color = condition), method = "pearson")

ZirFlu$HAItiter %>% 
  ggscatter(x = "Byamagata_T2", y = "H1N1_T3", color = "condition", add = "reg.line") +
  stat_cor(aes(color = condition), method = "pearson")

# check the percent of change -------------------------------------
HAItiter2 <- ZirFlu$HAItiter %>%
  mutate(H1N1_T3vsT2 = (H1N1_T3 - H1N1_T2)/H1N1_T2,
         H3N2_T3vsT2 = (H3N2_T3 - H3N2_T2)/H3N2_T2,
         Bvictoria_T3vsT2 = (Bvictoria_T3 - Bvictoria_T2)/Bvictoria_T2,
         Byamagata_T3vsT2 = (Byamagata_T3 - Byamagata_T2)/Byamagata_T2)

datPlot3 <- HAItiter2 %>% select(patientID, season, condition,  matches("T3vsT2")) %>%
  pivot_longer(!c("patientID", "season", "condition"), 
               names_to = "strains", values_to = "propotion_T3vsT2") %>%
  mutate(condition = factor(condition, 
                            levels = c("healthy", "compensated cirrhosis", "decompensated cirrhosis"))) %>%
  mutate(disease = ifelse(condition == "healthy", "healthy", "cirrhosis")) %>%
  mutate(disease = factor(disease,
                          levels = c("healthy", "cirrhosis")))

bxp3 <- datPlot3 %>%
  ggboxplot(x = "season", y = "propotion_T3vsT2", fill = "condition",
            bxp.errorbar = TRUE, palette = "npg",
            outlier.shape = 1, outlier.size = 2, outlier.color = "grey")

stat.test_condition3 <- datPlot3 %>% group_by(season) %>%
  t_test(propotion_T3vsT2 ~ condition)%>% add_xy_position(x = "season", dodge = 0.8)

stat.test_condition_strain3 <- datPlot3 %>% group_by(season, strains) %>%
  t_test(propotion_T3vsT2 ~ condition)%>% add_xy_position(x = "season", dodge = 0.8)

bxp3 + 
  stat_pvalue_manual(
    stat.test_condition3, label = "p.adj", tip.length = 0.02, bracket.nudge.y = 0.1)  + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.1)))

# specific strain case
datPlot4 <- datPlot3 %>% 
  #filter(str_detect(strains, "Bvictoria")) 
  filter(str_detect(strains, "H3N2"))

bxp4 <- datPlot4 %>%
  ggboxplot(x = "season", y = "propotion_T3vsT2", fill = "condition",
            bxp.errorbar = TRUE, palette = "npg",
            outlier.shape = 1, outlier.size = 2, outlier.color = "grey")

stat.test4 <- datPlot4 %>% group_by(season) %>%
  t_test(propotion_T3vsT2 ~ condition)%>% add_xy_position(x = "season", dodge = 0.8)

bxp4 + 
  stat_pvalue_manual(
    stat.test4, label = "p.adj", tip.length = 0.01, bracket.nudge.y = 0.1)  + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) + 
  #ylab("propotion_T3vsT2_Bvictoria")
  ylab("propotion_T3vsT2_H3N2")
