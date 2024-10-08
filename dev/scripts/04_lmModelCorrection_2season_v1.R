library(tidyverse)
library(lme4)
library(lmerTest)
library(broom.mixed)
library(ggpubr)
library(ggVennDiagram)
library(ComplexHeatmap)
# specific function for this code ---------------------------
get.lm_forDat <- function(inputDat, varList) {
  lm_results <- list()
  abTiters <- c("H1N1_abFC", "H3N2_abFC", 
                "Bvictoria_abFC", "Byamagata_abFC")
  for (name in abTiters) {
    lm_results[[name]] <- get.lmTest_correction(variableList = varList,
                                                abTiter = name, inputDat = inputDat)
  }
  return(lm_results)
}

get.lm_padj <- function(lm_results) {
  lm_padj <- list()
  for (i in names(lm_results)) {
    dat_temp <- p.adjust(lm_results[[i]]$p.value, method = "fdr")
    lm_padj[[i]] <- cbind(lm_results[[i]], "p.adj" = dat_temp)
  }
  return(lm_padj)
}

get.var_associFactor <- function(lm_results) {
  var_associDisease <- list()
  var_associAbTiter <- list()
  var_onlyAbTiter <- list()
  
  for (i in names(lm_results)) {
    var_associDisease[[i]] <- lm_results[[i]] %>% filter(p.value < 0.05) %>%
      filter(independentVariable == "diseasehealthy")
    
    var_associAbTiter[[i]] <- lm_results[[i]] %>% filter(p.value < 0.05) %>%
      filter(independentVariable == "abTiter")
    
    var_onlyAbTiter[[i]] <- get.var_onlyAbTiter(var_associAbTiter, 
                                                var_associDisease,
                                                abTiter = i)
  }
  return(list("var_associDisease" = var_associDisease, 
              "var_associAbTiter" = var_associAbTiter, 
              "var_onlyAbTiter" = var_onlyAbTiter))
}
get.var_associFactor_padj <- function(lm_results) {
  var_associDisease <- list()
  var_associAbTiter <- list()
  var_onlyAbTiter <- list()
  
  for (i in names(lm_results)) {
    var_associDisease[[i]] <- lm_results[[i]] %>% filter(p.adj < 0.05) %>%
      filter(independentVariable == "diseasehealthy")
    
    var_associAbTiter[[i]] <- lm_results[[i]] %>% filter(p.adj < 0.05) %>%
      filter(independentVariable == "abTiter")
    
    var_onlyAbTiter[[i]] <- get.var_onlyAbTiter(var_associAbTiter, 
                                                var_associDisease,
                                                abTiter = i)
  }
  return(list("var_associDisease" = var_associDisease, 
              "var_associAbTiter" = var_associAbTiter, 
              "var_onlyAbTiter" = var_onlyAbTiter))
}

get.targetedVar <- function(inputDat) {
  outcome <- inputDat %>% 
    lapply(function(x) x %>% select(targetVariable))
  return(outcome)
}
# venn diagram
get.vennDat <- function(inputDat, time) {
  dat_temp <- inputDat %>% lapply(function(x) x%>% select(targetVariable))
  outcome <- dat_temp[grep(time, names(dat_temp))] %>% unlist(recursive = FALSE)
  names(outcome) <- substring(names(outcome), 1, 7)
  return(outcome)
}

get.vennPlot_pertime <- function(var_associDisease, var_associAbTiter, time) {
  cowplot::plot_grid(
    ggVennDiagram(get.vennDat(var_associDisease, time),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associAbTiter, time),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    labels = c("Disease-associated", "abTiterFC-associated"), nrow = 2)
}

get.vennPlot_allTime <- function(var_associDisease, var_associAbTiter) {
  cowplot::plot_grid(
    ggVennDiagram(get.vennDat(var_associDisease, "T1"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associAbTiter, "T1"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associDisease, "T3"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associAbTiter, "T3"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associDisease, "T4"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    ggVennDiagram(get.vennDat(var_associAbTiter, "T4"),
                  label_alpha = 0) + scale_fill_gradient(low="white",high = "blue"),
    byrow = FALSE
  )
}

# make heatmap
get.lmStatistic <- function(inputDat) {
  outcome <- inputDat %>% 
    lapply(function(x) x %>% select(targetVariable, statistic)) %>% 
    bind_rows(.id = "groups") %>% mutate(groups = substring(groups, 1, 7)) %>%
    pivot_wider(names_from = groups, values_from = statistic) %>% 
    column_to_rownames("targetVariable")
  return(outcome)
}

get.dat_sigPvalue <- function(inputDat, lm_sigPvalue) {
  outcome <- as.data.frame(matrix(nrow=0, ncol = 4))
  for (name in names(lm_sigPvalue)) {
    dat_temp <- inputDat %>% filter(time == substring(name, 1, 7)) %>% 
      mutate(significance = ifelse(OlinkID %in% lm_sigPvalue[[name]], TRUE, NA))
    outcome <- rbind(outcome, dat_temp)
  }
  return(outcome)
}

get.dat_sigPvalue_metabolite <- function(inputDat, lm_sigPvalue) {
  outcome <- as.data.frame(matrix(nrow=0, ncol = 4))
  for (name in names(lm_sigPvalue)) {
    dat_temp <- inputDat %>% filter(time == substring(name, 1, 7)) %>% 
      mutate(significance = ifelse(ionIdx %in% lm_sigPvalue[[name]], TRUE, NA))
    outcome <- rbind(outcome, dat_temp)
  }
  return(outcome)
}
# protein with lm() model ---------------------------------------------------
inputDat_protein <- ZirFlu$donorSamples %>% 
  full_join(ZirFlu$donorInfo) %>% filter(time == "T1") %>%
  filter(patientID %in% ZirFlu$HAItiter$patientID) %>%
  left_join(ZirFlu$protein_dat %>% rownames_to_column("probenID"))

# per season 
input_protein <- list()
input_protein[["2019"]] <- ZirFlu$HAItiter_2019 %>% 
  left_join(inputDat_protein %>% filter(season == "2019"))
input_protein[["2020"]] <- ZirFlu$HAItiter_2020 %>% 
  left_join(inputDat_protein %>% filter(season == "2020"))

lmRes_protein <- list()
for (season in c("2019", "2020")) {
  lmRes_protein[[season]]$lmRes <- get.lm_forDat(input_protein[[season]], 
                                                 varList = names(ZirFlu$protein_dat))
  lmRes_protein[[season]]$lmAdj <- lmRes_protein[[season]]$lmRes %>% get.lm_padj()
  lmRes_protein[[season]]$sig <- lmRes_protein[[season]]$lmRes %>% get.var_associFactor()
  lmRes_protein[[season]]$sigAdj <- lmRes_protein[[season]]$lmAdj %>% get.var_associFactor_padj()
}

# save result
save(lmRes_protein, file = "temp/lmResult_protein_2seasons.RData")

## venn diagram(need to check later)  -------------------
load("temp/lmResult_protein_2seasons.RData")

## check top protein ---
proSig_onlyAb_2019 <- unique(unlist(lmRes_protein$`2019`$sig$var_onlyAbTiter))
proSig_onlyAb_2020 <- unique(unlist(lmRes_protein$`2020`$sig$var_onlyAbTiter))
intersect(proSig_onlyAb_2019, proSig_onlyAb_2020)

proSig_onlyAb_padj_2019 <- unique(unlist(lmRes_protein$`2019`$sigAdj$var_onlyAbTiter))
proSig_onlyAb_padj_2020 <- unique(unlist(lmRes_protein$`2020`$sigAdj$var_onlyAbTiter))

a <- get.proteinAnnot(ZirFlu$protein_annot, c(proSig_onlyAb_padj_2019, proSig_onlyAb_padj_2020)) 

# proteins_sigAssociDisease <- get.targetedVar(proteins_sig$var_associDisease)
# length(unique(proteins_sigAssociDisease %>% unlist()))
# 
# proteins_sigAssociAbFC <- get.targetedVar(proteins_sig$var_associAbTiter)
# sigProteinT1_Ab_pvalue <- unique(proteins_sigAssociAbFC %>% unlist())
# 
# proteins_sigAssociAbFC_padj <- get.targetedVar(proteins_sig_adj$var_associAbTiter)
# sigProteinT1_Ab_padj <- unique(proteins_sigAssociAbFC_padj %>% unlist())
# 
# sigProteinT1_onlyAb_pvalue <- unique(proteins_sig$var_onlyAbTiter %>% unlist())
# sigProteinT1_onlyAb_padj <- unique(proteins_sig_adj$var_onlyAbTiter %>% unlist())

# heatmap --------------------
selected_proteins <- c(proSig_onlyAb_padj_2019, proSig_onlyAb_padj_2020)

plotDat_wide <- list()
plotDat_long <- list()
for (season in c("2019", "2020")) {
  varlmAbTiter <- lmRes_protein[[season]]$lmRes %>% 
    lapply(function(x) x%>% filter(independentVariable == "abTiter")) %>%
    get.lmStatistic()
  
  heatmapDat <- varlmAbTiter[which(rownames(varlmAbTiter) %in% selected_proteins),]
  
  plotDat_wide[[season]] <- heatmapDat %>% #as.data.frame %>% 
    rownames_to_column("OlinkID") %>% left_join(ZirFlu$protein_annot) %>%
    select(-c(OlinkID, UniProt)) %>% column_to_rownames("Assay")
  
  plotDat_long[[season]] <- heatmapDat %>% #as.data.frame() %>% 
    rownames_to_column("OlinkID") %>% left_join(ZirFlu$protein_annot) %>%
    pivot_longer(cols = c(2:5), names_to = "time", values_to = "statistic") %>%
    #get.dat_sigPvalue(., lm_sigPvalue = lmRes_protein[[season]]$sig$var_onlyAbTiter)
    get.dat_sigPvalue(., lm_sigPvalue = lmRes_protein[[season]]$sigAdj$var_onlyAbTiter)
}

plotDat_wide_2seasons <- plotDat_wide$`2019` %>% rownames_to_column("protein") %>%
  rename("2019_H1N1" = "H1N1_ab", "2019_H3N2" = "H3N2_ab",
         "2019_Bvic" = "Bvictor", "2019_Byam"= "Byamaga") %>% 
  full_join(plotDat_wide$`2020` %>% rownames_to_column("protein") %>%
          rename("2020_H1N1" = "H1N1_ab", "2020_H3N2" = "H3N2_ab",
                 "2020_Bvic" = "Bvictor", "2020_Byam" = "Byamaga")) %>%
  column_to_rownames("protein")

plotDat_wide_2seasons %>% as.matrix() %>% heatmap(Colv = NA, Rowv = NA)
plotDat_wide_2seasons %>% as.matrix() %>% Heatmap()
plotDat_wide_2seasons %>% as.matrix() %>% Heatmap(cluster_columns = FALSE)

plotDat_long_2seasons <- plotDat_long$`2019` %>% mutate(season = "2019") %>%
  rbind(plotDat_long$`2020` %>% mutate(season = "2020")) %>%
  unite(time, season, time) %>% mutate(time = substring(time, 1, 9))

plotDat_long_2seasons  %>% 
  ggplot(aes(x = time, y = Assay)) + 
  geom_tile(aes(fill = statistic)) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

plotDat_long_2seasons %>% 
  ggplot(aes(x = time, y = Assay)) + 
  geom_tile(aes(fill = statistic)) +
  scale_y_discrete(limits = plotDat_long_2seasons$Assay[hclust(dist(plotDat_wide_2seasons))$order])+
  geom_text(aes(label = ifelse(significance == TRUE, "*", ""))) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) + theme_bw()

# check complex heatmap package

# metabolite with lm() model ---------------------------------------------------
inputDat_metabolite <- ZirFlu$donorSamples %>% 
  full_join(ZirFlu$donorInfo) %>% filter(time == "T1") %>%
  filter(patientID %in% ZirFlu$HAItiter$patientID) %>%
  left_join(ZirFlu$metabolite_dat %>% rownames_to_column("probenID"))

# per season
input_metabolite <- list()
input_metabolite[["2019"]] <- ZirFlu$HAItiter_2019 %>% 
  left_join(inputDat_metabolite %>% filter(season == "2019"))
input_metabolite[["2020"]] <- ZirFlu$HAItiter_2020 %>% 
  left_join(inputDat_metabolite %>% filter(season == "2020"))

lmRes_metabolite <- list()
for (season in c("2019", "2020")) {
  lmRes_metabolite[[season]]$lmRes <- get.lm_forDat(input_metabolite[[season]], 
                                                 varList = names(ZirFlu$metabolite_dat))
  lmRes_metabolite[[season]]$lmAdj <- lmRes_metabolite[[season]]$lmRes %>% get.lm_padj()
  lmRes_metabolite[[season]]$sig <- lmRes_metabolite[[season]]$lmRes %>% get.var_associFactor()
  lmRes_metabolite[[season]]$sigAdj <- lmRes_metabolite[[season]]$lmAdj %>% get.var_associFactor_padj()
}

# save result
save(lmRes_metabolite, file = "temp/lmResult_metabolite_2seasons.RData")
## venn diagram (need to check later) -------------------
load("temp/lmResult_metabolite_2seasons.RData")

## check top metabolite ----------------------------
metaSig_onlyAb_2019 <- unique(unlist(lmRes_metabolite$`2019`$sig$var_onlyAbTiter))
metaSig_onlyAb_2020 <- unique(unlist(lmRes_metabolite$`2020`$sig$var_onlyAbTiter))
intersect(metaSig_onlyAb_2019, metaSig_onlyAb_2020)

metaSig_onlyAb_padj_2019 <- unique(unlist(lmRes_metabolite$`2019`$sigAdj$var_onlyAbTiter))
metaSig_onlyAb_padj_2020 <- unique(unlist(lmRes_metabolite$`2020`$sigAdj$var_onlyAbTiter))

a <- get.metaboliteAnnot(ZirFlu$metabolite_annot, c(metaSig_onlyAb_padj_2019, metaSig_onlyAb_padj_2020)) 

# metabolite_sigAssociDisease <- get.targetedVar(metabolite_sig$var_associDisease)
# metaboliteT1_disease_pvalue <- unique(metabolite_sigAssociDisease[1:4] %>% unlist())
# 
# metabolite_sigAssociAbFC <- get.targetedVar(metabolite_sig$var_associAbTiter)
# metaboliteT1_Ab_pvalue <- unique(metabolite_sigAssociAbFC[1:4] %>% unlist())
# 
# metabolite_sigAssociDisease_adj <- get.targetedVar(metabolite_sig_adj$var_associDisease)
# metaboliteT1_disease_padj <- unique(metabolite_sigAssociDisease_adj[1:4] %>% unlist())
# 
# metabolite_sigAssociAbFC_padj <- get.targetedVar(metabolite_sig_adj$var_associAbTiter)
# metaboliteT1_Ab_padj <- unique(metabolite_sigAssociAbFC_padj[1:4] %>% unlist())
# 
# metaboliteT1_onlyAb_pvalue <- unique(metabolite_sig$var_onlyAbTiter[1:4] %>% unlist())
# metaboliteT1_onlyAb_padj <- unique(metabolite_sig_adj$var_onlyAbTiter[1:4] %>% unlist())

# heatmap --------------------
selected_metabolites <- c(metaSig_onlyAb_padj_2019, metaSig_onlyAb_padj_2020)
selected_metabolites <- c(metaSig_onlyAb_padj_2019, metaSig_onlyAb_padj_2020,
                          intersect(metaSig_onlyAb_2019, metaSig_onlyAb_2020))

plotDat_wide <- list()
plotDat_long <- list()
for (season in c("2019", "2020")) {
  varlmAbTiter <- lmRes_metabolite[[season]]$lmRes %>% 
    lapply(function(x) x%>% filter(independentVariable == "abTiter")) %>%
    get.lmStatistic()
  
  heatmapDat <- varlmAbTiter[which(rownames(varlmAbTiter) %in% selected_metabolites),]
  
  plotDat_wide[[season]] <- heatmapDat %>% #as.data.frame %>% 
    rownames_to_column("ionIdx") %>% mutate(ionIdx = as.numeric(ionIdx)) %>%
    left_join(ZirFlu$metabolite_annot %>% select(ionIdx, Formula) %>% distinct()) %>%
    select(-c(ionIdx)) %>% column_to_rownames("Formula")
  
  plotDat_long[[season]] <- heatmapDat %>% #as.data.frame() %>% 
    rownames_to_column("ionIdx") %>% mutate(ionIdx = as.numeric(ionIdx)) %>%
    left_join(ZirFlu$metabolite_annot %>% select(ionIdx, Formula) %>% distinct()) %>%
    pivot_longer(cols = c(2:5), names_to = "time", values_to = "statistic") %>%
    #get.dat_sigPvalue_metabolite(., lm_sigPvalue = lmRes_metabolite[[season]]$sig$var_onlyAbTiter)
    get.dat_sigPvalue_metabolite(., lm_sigPvalue = lmRes_metabolite[[season]]$sigAdj$var_onlyAbTiter)
}

plotDat_wide_2seasons <- plotDat_wide$`2019` %>% rownames_to_column("metabolite") %>%
  rename("2019_H1N1" = "H1N1_ab", "2019_H3N2" = "H3N2_ab",
         "2019_Bvic" = "Bvictor", "2019_Byam"= "Byamaga") %>% 
  full_join(plotDat_wide$`2020` %>% rownames_to_column("metabolite") %>%
              rename("2020_H1N1" = "H1N1_ab", "2020_H3N2" = "H3N2_ab",
                     "2020_Bvic" = "Bvictor", "2020_Byam" = "Byamaga")) %>%
  column_to_rownames("metabolite")

plotDat_wide_2seasons %>% as.matrix() %>% heatmap(Colv = NA, Rowv = NA)
plotDat_wide_2seasons %>% as.matrix() %>% Heatmap()
plotDat_wide_2seasons %>% as.matrix() %>% Heatmap(cluster_columns = FALSE)

plotDat_long_2seasons <- plotDat_long$`2019` %>% mutate(season = "2019") %>%
  rbind(plotDat_long$`2020` %>% mutate(season = "2020")) %>%
  unite(time, season, time) %>% mutate(time = substring(time, 1, 9))

plotDat_long_2seasons  %>% 
  ggplot(aes(x = time, y = Formula)) + 
  geom_tile(aes(fill = statistic)) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

plotDat_long_2seasons %>% 
  ggplot(aes(x = time, y = Formula)) + 
  geom_tile(aes(fill = statistic)) +
  scale_y_discrete(limits = plotDat_long_2seasons$Assay[hclust(dist(plotDat_wide_2seasons))$order])+
  geom_text(aes(label = ifelse(significance == TRUE, "*", ""))) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) + theme_bw()

