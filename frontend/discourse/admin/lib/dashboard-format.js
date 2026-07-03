import I18n from "discourse-i18n";

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
