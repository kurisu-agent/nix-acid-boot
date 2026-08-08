# Color palettes.
#
# `logoFilter` recolors a *duotone* source (the stock blue nix-snowflake)
# by rotating its hue, which keeps its two tones distinct. `tint` is the
# flat color used for *line-art* sources — a hue rotation can't color
# white strokes, so those are masked and filled instead. Every other key
# is a plymouth-script "r, g, b" triplet in 0-1 floats.
{
  nix-blue = {
    logoFilter = "-modulate 100,130,100";
    tint = "#7eb1dd";
    promptColor = "0.32, 0.47, 0.76";
    entryColor = "0.49, 0.73, 0.89";
    logDefaultColor = "0.60, 0.80, 0.95";
    logOkColor = "0.32, 0.47, 0.76";
    logFailColor = "1.00, 0.30, 0.25";
    logWarnColor = "0.95, 0.80, 0.20";
    msgColor = "0.45, 0.60, 0.80";
  };

  furry-pink = {
    logoFilter = "-modulate 110,200,161";
    tint = "#ff6fc0";
    promptColor = "0.95, 0.45, 0.75";
    entryColor = "1.00, 0.60, 0.85";
    logDefaultColor = "1.00, 0.65, 0.85";
    logOkColor = "0.80, 0.30, 0.60";
    logFailColor = "1.00, 0.25, 0.20";
    logWarnColor = "0.95, 0.80, 0.20";
    msgColor = "0.85, 0.50, 0.70";
  };

  acid-green = {
    logoFilter = "-modulate 105,230,25 -level 0%,95%";
    tint = "#ccff00";
    promptColor = "0.62, 0.90, 0.10";
    entryColor = "0.80, 1.00, 0.00";
    logDefaultColor = "0.80, 1.00, 0.20";
    logOkColor = "0.45, 0.62, 0.10";
    logFailColor = "1.00, 0.28, 0.16";
    logWarnColor = "0.95, 0.82, 0.15";
    msgColor = "0.45, 0.65, 0.20";
  };

  doom-red = {
    logoFilter = "-modulate 100,230,181";
    tint = "#ff5a33";
    promptColor = "0.85, 0.20, 0.12";
    entryColor = "1.00, 0.35, 0.20";
    logDefaultColor = "1.00, 0.45, 0.30";
    logOkColor = "0.65, 0.15, 0.10";
    logFailColor = "1.00, 0.20, 0.10";
    logWarnColor = "1.00, 0.65, 0.15";
    msgColor = "0.75, 0.30, 0.20";
  };

  golden-yellow = {
    logoFilter = "-modulate 108,220,6";
    tint = "#ffc233";
    promptColor = "0.98, 0.76, 0.20";
    entryColor = "1.00, 0.86, 0.35";
    logDefaultColor = "1.00, 0.85, 0.40";
    logOkColor = "0.72, 0.55, 0.12";
    logFailColor = "1.00, 0.30, 0.20";
    logWarnColor = "1.00, 0.70, 0.15";
    msgColor = "0.85, 0.68, 0.25";
  };

  cool-gray = {
    logoFilter = "-modulate 100,12,100";
    tint = "#d8dde2";
    promptColor = "0.75, 0.78, 0.82";
    entryColor = "0.92, 0.94, 0.96";
    logDefaultColor = "0.80, 0.83, 0.86";
    logOkColor = "0.55, 0.58, 0.62";
    logFailColor = "1.00, 0.35, 0.30";
    logWarnColor = "0.90, 0.78, 0.30";
    msgColor = "0.60, 0.63, 0.67";
  };
}
