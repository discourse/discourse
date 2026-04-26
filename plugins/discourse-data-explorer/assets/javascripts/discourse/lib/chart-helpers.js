export const SERIES_COLORS = [
  "#1EB8D1",
  "#9BC53D",
  "#721D8D",
  "#E84A5F",
  "#8A6916",
  "#FFCD56",
];

export function looksLikeDate(value) {
  if (!value || typeof value !== "string") {
    return false;
  }
  return /^\d{4}-\d{2}-\d{2}/.test(value);
}

export function isNumericColumn(rows, colIndex) {
  for (const row of rows) {
    const val = row[colIndex];
    if (val !== null && val !== undefined && val !== "") {
      return Number.isFinite(Number(val));
    }
  }
  return false;
}
