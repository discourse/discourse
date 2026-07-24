export const PERIOD_LAST_7_DAYS = "last_7_days";
export const PERIOD_LAST_30_DAYS = "last_30_days";
export const PERIOD_LAST_3_MONTHS = "last_3_months";
export const PERIOD_LAST_6_MONTHS = "last_6_months";
export const PERIOD_LAST_YEAR = "last_year";
export const PERIOD_CUSTOM = "custom";

export const DEFAULT_PERIOD = PERIOD_LAST_30_DAYS;

export const ALL_PRESETS = [
  PERIOD_LAST_7_DAYS,
  PERIOD_LAST_30_DAYS,
  PERIOD_LAST_3_MONTHS,
  PERIOD_LAST_6_MONTHS,
  PERIOD_LAST_YEAR,
];

export const VALID_PERIODS = [...ALL_PRESETS, PERIOD_CUSTOM];

export const PRESET_LABEL_KEYS = {
  [PERIOD_LAST_7_DAYS]: "date_range_picker.presets.last_7_days",
  [PERIOD_LAST_30_DAYS]: "date_range_picker.presets.last_30_days",
  [PERIOD_LAST_3_MONTHS]: "date_range_picker.presets.last_3_months",
  [PERIOD_LAST_6_MONTHS]: "date_range_picker.presets.last_6_months",
  [PERIOD_LAST_YEAR]: "date_range_picker.presets.last_year",
};

const PRESET_RANGES = {
  [PERIOD_LAST_7_DAYS]: (today) => today.clone().subtract(6, "days"),
  [PERIOD_LAST_30_DAYS]: (today) => today.clone().subtract(29, "days"),
  [PERIOD_LAST_3_MONTHS]: (today) =>
    today.clone().subtract(3, "months").add(1, "day"),
  [PERIOD_LAST_6_MONTHS]: (today) =>
    today.clone().subtract(6, "months").add(1, "day"),
  [PERIOD_LAST_YEAR]: (today) =>
    today.clone().subtract(1, "year").add(1, "day"),
};

export function calculatePresetStartDate(period) {
  const startFor = PRESET_RANGES[period] ?? PRESET_RANGES[DEFAULT_PERIOD];
  return startFor(moment().startOf("day")).toDate();
}

export function formatRange(from, to) {
  if (!from || !to) {
    return "";
  }
  const fromM = moment(from);
  const toM = moment(to);
  if (fromM.isSame(toM, "day")) {
    return fromM.format("ll");
  }
  return `${fromM.format("ll")} – ${toM.format("ll")}`;
}
