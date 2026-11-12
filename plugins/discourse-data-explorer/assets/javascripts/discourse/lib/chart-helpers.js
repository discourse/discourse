import { isEmpty } from "@ember/utils";
import moment from "moment";

export const SERIES_COLORS = [
  "#1EB8D1",
  "#9BC53D",
  "#721D8D",
  "#E84A5F",
  "#8A6916",
  "#FFCD56",
];

const DATE_LABEL_FORMATS = ["MMM D", "MMM DD", "MMM YY", "MMM YYYY"];
const MONTH_DAY_LABEL_FORMATS = ["MMM D", "MMM DD"];

const ISO_DATE = /^\d{4}-\d{2}-\d{2}/;

function normalizedLabel(value) {
  if (!value || typeof value !== "string") {
    return null;
  }

  return value.trim().replace(/\s+/g, " ");
}

export function looksLikeDate(value) {
  const label = normalizedLabel(value);
  if (!label) {
    return false;
  }

  return (
    ISO_DATE.test(label) || moment(label, DATE_LABEL_FORMATS, true).isValid()
  );
}

export function formatChartDateLabel(value) {
  const label = normalizedLabel(value);
  if (!label) {
    return value;
  }

  if (ISO_DATE.test(label)) {
    return moment(label).format("LL");
  }

  const monthDay = moment(label, MONTH_DAY_LABEL_FORMATS, true);
  if (monthDay.isValid()) {
    return monthDay.format("MMM D");
  }

  return label;
}

export function hasDates(rows) {
  return rows?.length > 0 && looksLikeDate(String(rows[0][0]));
}

export function chartDatasets(rows, numericIndices, labels) {
  return numericIndices.map((colIdx) => ({
    label: labels[colIdx],
    values: rows.map((row) => {
      const cell = row[colIdx];
      return isEmpty(cell) ? null : Number(cell);
    }),
  }));
}

export function isNumericColumn(rows, colIndex) {
  for (const row of rows) {
    const val = row[colIndex];
    if (!isEmpty(val)) {
      return Number.isFinite(Number(val));
    }
  }
  return false;
}

const MAX_DEFAULT_CATEGORICAL_ROWS = 25;
const MAX_DEFAULT_TIME_SERIES = 4;
const MIN_DEFAULT_NUMERIC_DENSITY = 0.5;

// Picks the view to show when the user hasn't expressed a preference. A chart
// is only a good default when every non-label column can be plotted; if
// charting would silently drop columns (e.g. "user, username, reason, sum"),
// the table is more honest. We also keep large categorical and sparse
// multi-series result sets in table view by default; users can still toggle to
// the chart.
export function defaultView(content) {
  const ability = chartability(content);
  if (!ability.chartable || ability.ignoredColumns.length > 0) {
    return "table";
  }
  if (shouldDefaultToTable(content, ability)) {
    return "table";
  }
  return "chart";
}

function shouldDefaultToTable(content, ability) {
  const rows = content?.rows ?? [];
  const firstLabel = String(rows[0]?.[0]);

  if (
    !looksLikeDate(firstLabel) &&
    rows.length > MAX_DEFAULT_CATEGORICAL_ROWS
  ) {
    return true;
  }

  if (
    looksLikeDate(firstLabel) &&
    ability.numericIndices.length > MAX_DEFAULT_TIME_SERIES
  ) {
    return true;
  }

  if (ability.numericIndices.length > 1) {
    return (
      numericDensity(rows, ability.numericIndices) < MIN_DEFAULT_NUMERIC_DENSITY
    );
  }

  return false;
}

function numericDensity(rows, numericIndices) {
  const totalCells = rows.length * numericIndices.length;
  if (totalCells === 0) {
    return 0;
  }

  let presentCells = 0;
  for (const row of rows) {
    for (const index of numericIndices) {
      if (!isEmpty(row[index])) {
        presentCells++;
      }
    }
  }

  return presentCells / totalCells;
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
