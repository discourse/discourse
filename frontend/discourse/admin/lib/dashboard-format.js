import I18n, { i18n } from "discourse-i18n";

const HEADLINE_PERIOD_KEYS = {
  last_7_days: "admin.dashboard.headline_period.last_7_days",
  last_30_days: "admin.dashboard.headline_period.last_30_days",
  last_3_months: "admin.dashboard.headline_period.last_3_months",
};

export function formatDashboardHeadlinePeriod(period) {
  return i18n(
    HEADLINE_PERIOD_KEYS[period] ??
      "admin.dashboard.headline_period.selected_period"
  );
}

export function formatKpiValue(value, { percentage = false } = {}) {
  if (value == null) {
    return "—";
  }
  if (percentage) {
    return `${I18n.toNumber(value, { precision: 1 })}%`;
  }
  return I18n.toNumber(value, { precision: 0 });
}

export function formatDeltaPercent(value) {
  const abs = Math.abs(value);

  if (abs > 0 && abs < 1) {
    const sign = value > 0 ? "+" : "-";
    return `${sign}${I18n.toNumber(abs, { precision: 1 })}%`;
  }

  const rounded = Math.round(value);
  const sign = rounded > 0 ? "+" : "";
  return `${sign}${I18n.toNumber(rounded, { precision: 0 })}%`;
}
