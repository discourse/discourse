import { SCHEMA_VERSION } from "admin/models/report";

let signups = {
  type: "signups",
  title: "Signups",
  xaxis: "Day",
  yaxis: "Number of signups",
  description: "New account registrations for this period",
  data: [
    { x: "2018-06-16", y: "12" },
    { x: "2018-06-17", y: 16 },
    { x: "2018-06-18", y: 42 },
    { x: "2018-06-19", y: 38 },
    { x: "2018-06-20", y: 41 },
    { x: "2018-06-21", y: 32 },
    { x: "2018-06-22", y: 23 },
    { x: "2018-06-23", y: 23 },
    { x: "2018-06-24", y: 17 },
    { x: "2018-06-25", y: 27 },
    { x: "2018-06-26", y: 32 },
    { x: "2018-06-27", y: "7" }
  ],
  start_date: "2018-06-16T00:00:00Z",
  end_date: "2018-07-16T23:59:59Z",
  prev_data: [
    { x: "2018-05-17", y: 32 },
    { x: "2018-05-18", y: 30 },
    { x: "2018-05-19", y: 12 },
    { x: "2018-05-20", y: 23 },
    { x: "2018-05-21", y: 50 },
    { x: "2018-05-22", y: 39 },
    { x: "2018-05-23", y: 51 },
    { x: "2018-05-24", y: 48 },
    { x: "2018-05-25", y: 37 },
    { x: "2018-05-26", y: 17 },
    { x: "2018-05-27", y: 6 },
    { x: "2018-05-28", y: 20 },
    { x: "2018-05-29", y: 37 },
    { x: "2018-05-30", y: 37 },
    { x: "2018-05-31", y: 37 },
    { x: "2018-06-01", y: 38 },
    { x: "2018-06-02", y: 23 },
    { x: "2018-06-03", y: 18 },
    { x: "2018-06-04", y: 39 },
    { x: "2018-06-05", y: 26 },
    { x: "2018-06-06", y: 39 },
    { x: "2018-06-07", y: 52 },
    { x: "2018-06-08", y: 35 },
    { x: "2018-06-09", y: 19 },
    { x: "2018-06-10", y: 15 },
    { x: "2018-06-11", y: 31 },
    { x: "2018-06-12", y: 38 },
    { x: "2018-06-13", y: 30 },
    { x: "2018-06-14", y: 45 },
    { x: "2018-06-15", y: 37 },
    { x: "2018-06-16", y: 12 }
  ],
  prev_start_date: "2018-05-17T00:00:00Z",
  prev_end_date: "2018-06-17T00:00:00Z",
  prev30Days: null,
  dates_filtering: true,
  report_key: 'reports:signups:start:end:[:prev_period]:50:{"group":"88"}:4',
  available_filters: [
    { id: "group", allow_any: false, choices: [], default: "88" }
  ],
  labels: [
    { type: "date", properties: ["x"], title: "Day" },
    { type: "number", properties: ["y"], title: "Count" }
  ],
  average: false,
  percent: false,
  higher_is_better: true,
  modes: ["table", "chart"],
  prev_period: 961
};

let signups_fixture = JSON.parse(JSON.stringify(signups));
signups_fixture.type = "signups_exception";
signups_fixture.error = "exception";
const signups_exception = signups_fixture;

signups_fixture = JSON.parse(JSON.stringify(signups));
signups_fixture.type = "signups_timeout";
signups_fixture.error = "timeout";
const signups_timeout = signups_fixture;

signups_fixture = JSON.parse(JSON.stringify(signups));
signups_fixture.type = "not_found";
signups_fixture.error = "not_found";
const signups_not_found = signups_fixture;

const startDate = moment()
  .locale("en")
  .utc()
  .startOf("day")
  .subtract(1, "month");

const endDate = moment()
  .locale("en")
  .utc()
  .endOf("day");

const daysInQueryPeriod = endDate.diff(startDate, "days", false) + 1;

const data = [
  851,
  3805,
  2437,
  3768,
  4476,
  3021,
  1285,
  1120,
  3932,
  2777,
  3298,
  3198,
  3601,
  1249,
  1046,
  3212,
  3358,
  3306,
  2618,
  2679,
  910,
  875,
  3877,
  2342,
  2305,
  3534,
  3713,
  1133,
  1350,
  4048,
  2523,
  1062
].slice(-daysInQueryPeriod);

const page_view_total_reqs = {
  type: "page_view_total_reqs",
  title: "Pageviews",
  xaxis: "Day",
  yaxis: "Total Pageviews",
  description: null,
  data: [...data].map((d, i) => {
    return {
      x: moment(startDate)
        .add(i, "days")
        .format("YYYY-MM-DD"),
      y: d
    };
  }),
  start_date: startDate.toISOString(),
  end_date: endDate.toISOString(),
  prev_data: null,
  prev_start_date: "2018-06-20T00:00:00Z",
  prev_end_date: "2018-07-23T00:00:00Z",
  prev30Days: 58110,
  dates_filtering: true,
  report_key: `reports:page_view_total_reqs:start:end:[:prev_period]:${SCHEMA_VERSION}`,
  labels: [
    { type: "date", property: "x", title: "Day" },
    { type: "number", property: "y", title: "Count" }
  ],
  average: false,
  percent: false,
  higher_is_better: true,
  modes: ["table", "chart"],
  icon: "file",
  total: 921672
};

const staff_logins = JSON.parse(JSON.stringify(page_view_total_reqs));
staff_logins.type = "staff_logins";
staff_logins.modes = ["table"];
staff_logins.report_key = `reports:staff_logins:start:end:[:prev_period]:50:${SCHEMA_VERSION}`;

export default {
  "/admin/reports/bulk": {
    reports: [
      signups,
      signups_not_found,
      signups_exception,
      signups_timeout,
      page_view_total_reqs,
      staff_logins
    ]
  }
};
