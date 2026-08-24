import I18n from "discourse-i18n";

function roundHalfDown(value, unit) {
  return Math.floor((value + unit / 2 - 1) / unit) * unit;
}

export function formatPageviewCount(value) {
  if (value >= 1_000_000) {
    const rounded = roundHalfDown(value, 100_000);
    const formatted = I18n.toNumber(rounded / 1_000_000, { precision: 1 });
    return `${formatted.replace(/[,.]0$/, "")}M`;
  }

  if (value >= 10_000) {
    const rounded = roundHalfDown(value, 1_000);
    return `${I18n.toNumber(rounded / 1_000, { precision: 0 })}K`;
  }

  if (value >= 1_000) {
    const rounded = roundHalfDown(value, 100);
    const formatted = I18n.toNumber(rounded / 1_000, { precision: 1 });
    return `${formatted.replace(/[,.]0$/, "")}K`;
  }

  return I18n.toNumber(value, { precision: 0 });
}

export function isPageviewCountRounded(value) {
  if (value >= 1_000_000) {
    return value % 100_000 !== 0;
  }

  if (value >= 10_000) {
    return value % 1_000 !== 0;
  }

  return value >= 1_000 && value % 100 !== 0;
}

export function formatExactPageviewCount(value) {
  return I18n.toNumber(value, { precision: 0 });
}
