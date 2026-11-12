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

export function roundDeltaPercent(value) {
  const abs = Math.abs(value);

  if (abs > 0 && abs < 1) {
    const roundedAbs = Math.round(abs * 10) / 10;
    return value < 0 ? -roundedAbs : roundedAbs;
  }

  return Math.round(value);
}

export function formatDeltaPercent(value) {
  const rounded = roundDeltaPercent(value);

  if (Math.abs(value) > 0 && Math.abs(value) < 1) {
    const sign = value > 0 ? "+" : "-";
    return `${sign}${I18n.toNumber(Math.abs(rounded), { precision: 1 })}%`;
  }

  const sign = rounded > 0 ? "+" : "";
  return `${sign}${I18n.toNumber(rounded, { precision: 0 })}%`;
}
