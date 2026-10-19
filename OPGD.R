# ---------------------------------------------------------------
# 1. Environment setup and package loading
# ---------------------------------------------------------------
if (!require("GD")) {
  install.packages("GD")
  library(GD)
}

# ---------------------------------------------------------------
# 2. Data loading and preprocessing
# ---------------------------------------------------------------
data <- read.csv("YOUR_DATA_PATH/LP0.csv")

# Remove missing values
data <- na.omit(data)


# ---------------------------------------------------------------
# 3. Convert LUC to a categorical variable
# ---------------------------------------------------------------
# 1 = PC   Persistent Cropland
# 2 = PNV  Persistent Natural Vegetation
# 3 = ER   Ecological Restoration
# 4 = VLUE Vegetation Loss / Urban Expansion
# 5 = OT   Other Transitions

data$LUC <- factor(data$LUC)


# ---------------------------------------------------------------
# 4. Convert aspect to 9 classes
# ---------------------------------------------------------------
# -1        = FLAT
# 0-22.5    = N
# 22.5-67.5 = NE
# 67.5-112.5 = E
# 112.5-157.5 = SE
# 157.5-202.5 = S
# 202.5-247.5 = SW
# 247.5-292.5 = W
# 292.5-337.5 = NW
# 337.5-359  = N

data$Aspect_class <- NA_character_

# 1. Flat terrain
data$Aspect_class[data$Aspect == -1] <- "FLAT"

# 2. North-facing slope
data$Aspect_class[
  data$Aspect >= 0 & data$Aspect < 22.5
] <- "N"

data$Aspect_class[
  data$Aspect >= 337.5 & data$Aspect <= 359
] <- "N"

# 3. Northeast-facing slope
data$Aspect_class[
  data$Aspect >= 22.5 & data$Aspect < 67.5
] <- "NE"

# 4. East-facing slope
data$Aspect_class[
  data$Aspect >= 67.5 & data$Aspect < 112.5
] <- "E"

# 5. Southeast-facing slope
data$Aspect_class[
  data$Aspect >= 112.5 & data$Aspect < 157.5
] <- "SE"

# 6. South-facing slope
data$Aspect_class[
  data$Aspect >= 157.5 & data$Aspect < 202.5
] <- "S"

# 7. Southwest-facing slope
data$Aspect_class[
  data$Aspect >= 202.5 & data$Aspect < 247.5
] <- "SW"

# 8. West-facing slope
data$Aspect_class[
  data$Aspect >= 247.5 & data$Aspect < 292.5
] <- "W"

# 9. Northwest-facing slope
data$Aspect_class[
  data$Aspect >= 292.5 & data$Aspect < 337.5
] <- "NW"


# Convert to factor
data$Aspect_class <- factor(
  data$Aspect_class,
  levels = c(
    "FLAT",
    "N",
    "NE",
    "E",
    "SE",
    "S",
    "SW",
    "W",
    "NW"
  )
)


# ---------------------------------------------------------------
# Check the number of observations in each aspect class
# ---------------------------------------------------------------
cat("\n================ Aspect class statistics ================\n")
print(table(data$Aspect_class, useNA = "ifany"))


# ---------------------------------------------------------------
# 6. Define continuous explanatory variables
# ---------------------------------------------------------------
continuous_vars <- c(
  "DEM",
  "Slope",
  "lnGDP_slp",
  "lnPOP_slp",
  "lnNTL_slp",
  "PRE_slp",
  "TEM_slp",
  "SPEI_slp",
  "SM_slp"
)

# ---------------------------------------------------------------
# 7. Optimal discretization parameters for OPGD
# ---------------------------------------------------------------
# Discretization methods
discmethod <- c(
  "equal",
  "natural",
  "quantile",
  "geometric",
  "sd"
)

discitv <- 3:7


# ---------------------------------------------------------------
# 8. Run OPGD
# ---------------------------------------------------------------
cat("\n====================================================\n")
cat("Running OPGD\n")
cat("Number of classes for continuous variables: 3-7\n")
cat("Aspect: 9 classes (FLAT + 8 directions)\n")
cat("====================================================\n\n")


datagdm <- gdm(
  
  FVC_slp ~
    DEM +
    Slope +
    Aspect_class +
    LUC +
    lnGDP_slp +
    lnPOP_slp +
    lnNTL_slp +
    PRE_slp +
    TEM_slp +
    SPEI_slp +
    SM_slp,
  
  continuous_variable = continuous_vars,
  
  data = data,
  
  discmethod = discmethod,
  
  discitv = discitv
)


# ---------------------------------------------------------------
# 9. Display results
# ---------------------------------------------------------------
cat("\n================ OPGD Results ================\n")

print(datagdm)


# ---------------------------------------------------------------
# 10. Export results as PDF
# ---------------------------------------------------------------
pdf(
  "OPGD_results.pdf",
  width = 12,
  height = 9
)

plot(datagdm)

dev.off()


# ---------------------------------------------------------------
# 11. Completion message
# ---------------------------------------------------------------
message(
  "\nOPGD analysis completed.\n",
  "Results exported to: OPGD_results.pdf"
)
