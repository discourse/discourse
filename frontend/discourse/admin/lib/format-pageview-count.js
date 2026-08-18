import I18n from "discourse-i18n";

export function formatPageviewCount(value) {
  if (value >= 1_000_000) {
    const formatted = I18n.toNumber(value / 1_000_000, { precision: 1 });
    return `${formatted.replace(/[,.]0$/, "")}M`;
  }

  if (value >= 1_000) {
    return `${I18n.toNumber(Math.round(value / 1_000), { precision: 0 })}K`;
  }

  return I18n.toNumber(value, { precision: 0 });
}

export function formatExactPageviewCount(value) {
  return I18n.toNumber(value, { precision: 0 });
}
