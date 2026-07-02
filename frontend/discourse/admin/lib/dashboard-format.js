import I18n from "discourse-i18n";

const PERCENTAGE_KPIS = ["dau_mau"];

export function formatKpiValue(type, value) {
  if (value == null) {
    return "—";
  }
  if (PERCENTAGE_KPIS.includes(type)) {
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
