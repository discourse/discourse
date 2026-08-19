import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import { countryName } from "discourse/admin/lib/format-country";
import { ajax } from "discourse/lib/ajax";

export const FILTER_KEYS = [
  "traffic_type",
  "top_url",
  "entry_url",
  "referrer",
  "country",
  "network",
  "browser",
  "ip",
];

export const TRAFFIC_TYPES = ["logged_in", "anonymous", "likely_crawler"];

export function safePeriod({ range, start_date, end_date }) {
  if (!VALID_PERIODS.includes(range)) {
    return DEFAULT_PERIOD;
  }
  if (range === PERIOD_CUSTOM && (!start_date || !end_date)) {
    return DEFAULT_PERIOD;
  }
  return range;
}

export function startDate(params) {
  return (
    customDate(params.start_date, "startOf", params) ??
    calculatePresetStartDate(safePeriod(params))
  );
}

export function endDate(params) {
  return (
    customDate(params.end_date, "endOf", params) ??
    moment().endOf("day").toDate()
  );
}

export function selectedTrafficTypes(value) {
  if (!value) {
    return TRAFFIC_TYPES;
  }

  const selected = value.split(",");
  return TRAFFIC_TYPES.filter((trafficType) => selected.includes(trafficType));
}

export async function loadSiteTraffic(params) {
  const selectedStartDate = startDate(params);
  const selectedEndDate = endDate(params);
  const traffic = await ajax("/admin/dashboard/site-traffic-explorer.json", {
    data: requestParams(params),
  });

  return {
    ...localizeCountryLabels(traffic),
    chart_start_date: moment(selectedStartDate).format("YYYY-MM-DD"),
    chart_end_date: moment(selectedEndDate).format("YYYY-MM-DD"),
    chart_traffic_types: selectedTrafficTypes(params.traffic_type),
  };
}

function customDate(value, edge, params) {
  if (safePeriod(params) !== PERIOD_CUSTOM || !value) {
    return null;
  }

  const parsed = moment(value, "YYYY-MM-DD", true);
  return parsed.isValid() ? parsed[edge]("day").toDate() : null;
}

function requestParams(params) {
  const request = {
    start_date: moment(startDate(params)).format("YYYY-MM-DD"),
    end_date: moment(endDate(params)).format("YYYY-MM-DD"),
  };

  for (const key of FILTER_KEYS) {
    if (params[key] !== null && params[key] !== undefined) {
      request[key] = params[key];
    }
  }

  return request;
}

function localizeCountryLabels(traffic) {
  const countries = traffic.dimensions?.countries ?? [];
  const activeFilters = traffic.active_filters ?? [];

  return {
    ...traffic,
    dimensions: {
      ...traffic.dimensions,
      countries: countries.map((row) => ({
        ...row,
        label: countryName(row.value),
      })),
    },
    active_filters: activeFilters.map((filter) =>
      filter.key === "country"
        ? { ...filter, label: countryName(filter.value) }
        : filter
    ),
  };
}
