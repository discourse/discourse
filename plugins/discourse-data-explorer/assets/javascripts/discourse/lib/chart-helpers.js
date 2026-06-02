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

export function chartability(content) {
  const { rows, columns, colrender = {} } = content ?? {};
  if (!rows?.length) {
    return {
      chartable: false,
      numericIndices: [],
      ignoredColumns: [],
      reason: "no-rows",
    };
  }
  if (!columns?.length || columns.length < 2) {
    return {
      chartable: false,
      numericIndices: [],
      ignoredColumns: [],
      reason: "no-numeric",
    };
  }

  const numericIndices = [];
  const ignoredColumns = [];
  for (let i = 1; i < columns.length; i++) {
    if (colrender[i]) {
      ignoredColumns.push(columns[i]);
      continue;
    }
    if (typeof rows[0][i] === "number" || isNumericColumn(rows, i)) {
      numericIndices.push(i);
    } else {
      ignoredColumns.push(columns[i]);
    }
  }

  if (numericIndices.length === 0) {
    return {
      chartable: false,
      numericIndices,
      ignoredColumns,
      reason: "no-numeric",
    };
  }

  return {
    chartable: true,
    numericIndices,
    ignoredColumns,
    reason: ignoredColumns.length ? "chartable-with-ignored" : "chartable",
  };
}
