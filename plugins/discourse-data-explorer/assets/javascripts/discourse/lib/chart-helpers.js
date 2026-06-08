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

// Picks the view to show when the user hasn't expressed a preference. A chart
// is only a good default when every non-label column can be plotted; if
// charting would silently drop columns (e.g. "user, username, reason, sum"),
// the table is more honest. Users can still toggle to the chart.
export function defaultView(content) {
  const ability = chartability(content);
  if (!ability.chartable || ability.ignoredColumns.length > 0) {
    return "table";
  }
  return "chart";
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
