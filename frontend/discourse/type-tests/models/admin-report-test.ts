import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import Report, {
  DAILY_LIMIT_DAYS,
  type ReportCell,
  type ReportCellValue,
  type ReportCreateAttrs,
  type ReportData,
  type ReportPayload,
  type ReportPoint,
  type ReportRow,
  type ReportSeries,
  SCHEMA_VERSION,
  WEEKLY_LIMIT_DAYS,
} from "discourse/admin/models/report";
import type RestModel from "discourse/models/rest";

type Trend =
  | "high-trending-up"
  | "high-trending-down"
  | "trending-up"
  | "trending-down"
  | "no-change";
type TrendIcon =
  | "angle-up"
  | "angle-down"
  | "angles-up"
  | "angles-down"
  | "minus";

expectTypeOf(SCHEMA_VERSION).toEqualTypeOf<5>();
expectTypeOf(WEEKLY_LIMIT_DAYS).toEqualTypeOf<365>();
expectTypeOf(DAILY_LIMIT_DAYS).toEqualTypeOf<34>();

/* Statics. */

expectTypeOf(Report.groupingForDatapoints(10)).toEqualTypeOf<
  "daily" | "weekly" | "monthly" | undefined
>();
expectTypeOf(Report.unitForDatapoints(10)).toEqualTypeOf<
  "day" | "week" | "month"
>();
expectTypeOf(Report.unitForGrouping("weekly")).toEqualTypeOf<
  "day" | "week" | "month"
>();
// Chart options may leave the grouping unset.
Report.unitForGrouping(undefined);
// Charts collapse plain `{ start_date, end_date, data }` objects too, not only reports.
const collapsed = Report.collapse(
  { start_date: "2026-10-01", end_date: "2026-10-31" },
  [{ x: "2026-10-01", y: 1 }],
  "weekly"
);
expectTypeOf(collapsed).not.toBeAny();
expectTypeOf(collapsed).toExtend<{ x: string; y: number }[]>();
Report.collapse({ start_date: "2026-10-01", end_date: "2026-10-31" }, []);
// The options name the properties to read and write.
expectTypeOf(
  Report.fillMissingDates(
    {
      modes: ["chart"],
      data: [{ x: "2026-10-01", y: 1 }],
      start_date: "2026-10-01T00:00:00Z",
      end_date: "2026-10-31T23:59:59Z",
    },
    { filledField: "chartData" }
  )
).toEqualTypeOf<void>();
Report.fillMissingDates(
  { modes: ["chart"], data: [], prev_data: [] },
  {
    dataField: "prev_data",
    filledField: "prevChartData",
    startDate: "prev_start_date",
    endDate: "prev_end_date",
  }
);
Report.fillMissingDates(
  { modes: ["chart"], data: [] },
  // @ts-expect-error `startDate` is the option name
  { starDate: "prev_start_date" }
);
expectTypeOf(
  Report.find("topics", "2026-10-01", "2026-10-31")
).resolves.toEqualTypeOf<Report>();
Report.find("topics", "2026-10-01", "2026-10-31", 3, 4);

/* Construction from `/admin/reports/:type` payloads. */

Report.create({
  type: "topics",
  title: "Topics",
  xaxis: "Day",
  yaxis: "Number of new topics",
  description: "New topics created during this period.",
  description_link: null,
  data: [{ x: "2026-10-27", y: 1 }],
  start_date: "2026-10-27T00:00:00Z",
  end_date: "2026-11-26T23:59:59Z",
  prev_data: null,
  prev_start_date: "2026-09-26T00:00:00Z",
  prev_end_date: "2026-10-27T00:00:00Z",
  prev30Days: 0,
  dates_filtering: true,
  report_key: "reports:topics:20261027:20261126",
  primary_color: "rgba(0,136,204,1)",
  secondary_color: "rgba(0,136,204,0.1)",
  available_filters: [{ id: "category", type: "category", default: null }],
  labels: [
    { type: "date", property: "x", title: "Day" },
    { type: "number", property: "y", title: "Count" },
  ],
  average: false,
  percent: false,
  higher_is_better: true,
  modes: ["chart", "table"],
  total: 1,
  prev_period: 0,
  limit: 5,
});
// Stacked reports send series and translate each axis key.
Report.create({
  type: "visits",
  xaxis: { desktop: "Desktop", mobile: "Mobile" },
  data: [
    {
      req: "desktop",
      label: "Desktop",
      color: "#1EB8D1",
      data: [{ x: "2026-10-27", y: 1 }],
    },
  ],
  // SQL decimals arrive as strings.
  total: "2.0",
  icon: "user",
  default_group_by: "weekly",
});
Report.create({
  type: "user_flagging_ratio",
  title: null,
  data: [{ user_id: 1, username: "anne", score: "0.0" }],
  labels: [
    {
      type: "user",
      properties: {
        username: "username",
        id: "user_id",
        avatar: "avatar_template",
      },
      title: "User",
    },
    {
      type: "topic",
      properties: { title: "topic_title", id: "topic_id" },
      title: "Topic",
    },
    {
      type: "post",
      properties: {
        topic_id: "topic_id",
        number: "post_number",
        truncated_raw: "post_raw",
      },
      title: "Post",
    },
    { type: "link", properties: ["url", "title"], title: "Link" },
    { property: "share_formatted", title: "Share", sort_property: "share" },
    {
      type: "number",
      property: "like_count",
      title: "heart",
      html_title: "<img>",
    },
  ],
});
Report.create({
  type: "storage_stats",
  data: {
    backups: {
      used_bytes: 0,
      free_bytes: null,
      count: 0,
      last_backup_taken_at: null,
    },
    uploads: { used_bytes: 2062105, free_bytes: null },
  },
});
Report.create({
  type: "trust_level_pipeline",
  prev_period: { direction: "climbing", net: 2 },
});
Report.create({
  type: "web_hook_events_daily_aggregate",
  prev30Days: [],
  available_filters: [
    {
      id: "type_of_web_hook_event",
      type: "list",
      default: "all",
      choices: [{ id: "all", name: "all" }],
      allow_any: false,
      auto_insert_none_item: false,
    },
    { id: "groups", type: "groups", default: ["staff"] },
    { id: "category_ids", type: "category_list", default: [1, 2] },
    { id: "include_subcategories", type: "bool", default: false },
  ],
});
Report.create({
  type: "signups",
  related_items: {
    users: [
      {
        user: {
          id: 1,
          username: "bruce",
          name: null,
          avatar_template: "/a.png",
        },
        timestamp: "2026-10-28T00:32:54Z",
      },
    ],
  },
  related_items_totals: { users: 1 },
});
// Bulk responses send `error: null` for reports that loaded.
Report.create({ type: "topics", error: null, data: null });
Report.create({ type: "nonexistent", error: "not_found" });
// The dashboard provider adds `empty`.
Report.create({ type: "topics", empty: false });
// Some plugin reports send plain string labels.
Report.create({
  type: "sentiment_analysis",
  labels: ["Positive", "Negative", "Neutral"],
});
// @ts-expect-error the type is a string
Report.create({ type: 5 });

/* Instance fields. */

declare const report: Report;
expectTypeOf(report).toExtend<EmberObject>();
expectTypeOf(report).not.toExtend<RestModel>();
expectTypeOf(report).not.toBeAny();
expectTypeOf(report.type).toEqualTypeOf<string>();
expectTypeOf(report.title).toEqualTypeOf<string | null>();
expectTypeOf(report.yaxis).toEqualTypeOf<string | null>();
expectTypeOf(report.description).toEqualTypeOf<string | null>();
expectTypeOf(report.description_link).toEqualTypeOf<string | null>();
expectTypeOf(report.start_date).toEqualTypeOf<string>();
expectTypeOf(report.end_date).toEqualTypeOf<string>();
expectTypeOf(report.prev_start_date).toEqualTypeOf<string>();
expectTypeOf(report.prev_end_date).toEqualTypeOf<string>();
expectTypeOf(report.dates_filtering).toEqualTypeOf<boolean>();
expectTypeOf(report.report_key).toEqualTypeOf<string>();
expectTypeOf(report.primary_color).toEqualTypeOf<string>();
expectTypeOf(report.secondary_color).toEqualTypeOf<string>();
expectTypeOf(report.average).toEqualTypeOf<boolean>();
expectTypeOf(report.percent).toEqualTypeOf<boolean>();
expectTypeOf(report.higher_is_better).toEqualTypeOf<boolean>();
expectTypeOf(report.modes).toEqualTypeOf<string[]>();
expectTypeOf(report.limit).toEqualTypeOf<number | undefined>();
expectTypeOf(report.icon).toEqualTypeOf<string | undefined>();
expectTypeOf(report.default_group_by).toEqualTypeOf<string | undefined>();
expectTypeOf(report.y_axis_title).toEqualTypeOf<string | undefined>();
expectTypeOf(report.empty).toEqualTypeOf<boolean | undefined>();
expectTypeOf(report.error).toEqualTypeOf<
  "not_found" | "timeout" | "exception" | null | undefined
>();
// The report component records loader failures on the instance.
report.error = "exception";
expectTypeOf(report.data).not.toBeAny();
expectTypeOf(report.labels).not.toBeAny();
expectTypeOf(report.available_filters[0].id).toEqualTypeOf<string>();
expectTypeOf(report.xaxis).not.toBeAny();
expectTypeOf<null>().toExtend<Report["xaxis"]>();
expectTypeOf<null>().toExtend<Report["prev30Days"]>();
expectTypeOf<undefined>().toExtend<Report["prev_period"]>();
expectTypeOf<undefined>().toExtend<Report["total"]>();
expectTypeOf<undefined>().toExtend<Report["legacy"]>();
expectTypeOf(report.related_items).not.toBeAny();
expectTypeOf(report.related_items_totals).not.toBeAny();
expectTypeOf(report.relatedReport).toEqualTypeOf<Report | undefined>();
expectTypeOf(report.chartData).not.toBeAny();
expectTypeOf(report.prevChartData).not.toBeAny();

/* Derived values. */

expectTypeOf(report.reportUrl).toEqualTypeOf<string>();
expectTypeOf(report.combinedData).not.toBeAny();
expectTypeOf(report.todayCount).toEqualTypeOf<number>();
expectTypeOf(report.yesterdayCount).toEqualTypeOf<number>();
expectTypeOf(report.sevenDaysAgoCount).toEqualTypeOf<number>();
expectTypeOf(report.thirtyDaysAgoCount).toEqualTypeOf<number>();
expectTypeOf(report.lastSevenDaysCount).toEqualTypeOf<number | undefined>();
expectTypeOf(report.lastThirtyDaysCount).toEqualTypeOf<number | undefined>();
expectTypeOf(report.currentTotal).toEqualTypeOf<number>();
expectTypeOf(report.currentAverage).toEqualTypeOf<number>();
expectTypeOf(report.trend).toEqualTypeOf<Trend | undefined>();
expectTypeOf(report.yesterdayTrend).toEqualTypeOf<Trend | undefined>();
expectTypeOf(report.sevenDaysTrend).toEqualTypeOf<Trend | undefined>();
expectTypeOf(report.thirtyDaysTrend).toEqualTypeOf<Trend | undefined>();
expectTypeOf(report.trendIcon).toEqualTypeOf<TrendIcon>();
expectTypeOf(report.yesterdayTrendIcon).toEqualTypeOf<TrendIcon>();
expectTypeOf(report.sevenDaysTrendIcon).toEqualTypeOf<TrendIcon>();
expectTypeOf(report.thirtyDaysTrendIcon).toEqualTypeOf<TrendIcon>();
expectTypeOf(report.method).toEqualTypeOf<"average" | "sum">();
expectTypeOf(report.trendTitle).toEqualTypeOf<string>();
expectTypeOf(report.yesterdayCountTitle).toEqualTypeOf<string>();
expectTypeOf(report.sevenDaysCountTitle).toEqualTypeOf<string>();
expectTypeOf(report.thirtyDaysCountTitle).toEqualTypeOf<string>();
// Returns the comparison value itself, not a boolean.
expectTypeOf(report.canDisplayTrendIcon).toEqualTypeOf<
  NonNullable<Report["prev30Days"]> | Report["prev_period"]
>();
expectTypeOf(report.sortedData).not.toBeAny();
expectTypeOf(report.xAxisIsDate).toEqualTypeOf<
  false | RegExpMatchArray | null
>();
expectTypeOf(report.valueAt(1)).toEqualTypeOf<number>();
expectTypeOf(report.valueFor(1, 7)).toEqualTypeOf<number | undefined>();
expectTypeOf(report.percentChangeString(1, 2)).toEqualTypeOf<string | null>();
expectTypeOf(report.changeTitle(1, 2, "yesterday")).toEqualTypeOf<string>();

/* Table columns. */

const [column] = report.computedLabels;
expectTypeOf(column.title).toEqualTypeOf<string>();
expectTypeOf(column.htmlTitle).toEqualTypeOf<string | undefined>();
expectTypeOf(column.mainProperty).toEqualTypeOf<string>();
expectTypeOf(column.sortProperty).toEqualTypeOf<string>();
expectTypeOf(column.type).toEqualTypeOf<string>();
const cell = column.compute({ username: "anne", y: 3 });
expectTypeOf(cell).not.toBeAny();
expectTypeOf(cell).toHaveProperty("value");
expectTypeOf(cell).toHaveProperty("formattedValue");
column.compute({ y: 3 }, { useSortProperty: true });
column.compute({ y: 3 }, { formatNumbers: false });

/* Partial construction and raw hashes. */

const partial = Report.create({ type: "topics", data: [] });
expectTypeOf(partial).toEqualTypeOf<Report>();
expectTypeOf(Report.create()).toEqualTypeOf<Report>();
expectTypeOf<typeof Report>().toExtend<typeof EmberObject>();
expectTypeOf<ReportCreateAttrs>().toEqualTypeOf<Partial<Report>>();
expectTypeOf(partial.siteSettings).not.toBeAny();
Report.create({
  type: "web_hook_events_daily_aggregate",
  prev30Days: [
    {
      id: 1,
      date: null,
      mean_duration: "0.25",
      failed_event_count: null,
      successful_event_count: 2,
    },
  ],
  prev_period: [{ date: "2026-10-01", mean_duration: null }],
  chartData: [{ x: "2026-10-01", y: 1 }],
  prevChartData: [
    { label: "Previous", color: "red", data: [{ x: "2026-09-01", y: 0 }] },
  ],
});
// Related-item renderers read their own nested JSON.
Report.create({
  related_items: {
    custom_items: [{ topic: { title: "Example" }, users: [], category: null }],
  },
});
Report.fillMissingDates(partial);
Report.fillMissingDates(
  { modes: ["chart"], points: [], from: "2026-10-01", to: "2026-10-31" },
  {
    dataField: "points",
    filledField: "filled",
    startDate: "from",
    endDate: "to",
  }
);
expectTypeOf(
  Report.collapse(
    { start_date: new Date(), end_date: new Date(), average: true },
    []
  )
).toEqualTypeOf<ReportPoint[]>();
expectTypeOf<Report["data"]>().toEqualTypeOf<ReportData>();
expectTypeOf<Report["prev_data"]>().toEqualTypeOf<
  ReportPoint[] | ReportSeries[] | null
>();
expectTypeOf<ReportPayload>().not.toHaveProperty("computedLabels");
expectTypeOf(
  partial.computedLabels[0].compute({ score: "0.0" }).value
).toEqualTypeOf<ReportCellValue>();
expectTypeOf(partial._bytesLabel(10)).toEqualTypeOf<ReportCell>();
expectTypeOf(
  partial._numberLabel("2.0", { formatNumbers: false })
).toEqualTypeOf<ReportCell>();
expectTypeOf(partial.averageCount(7, undefined)).toEqualTypeOf<
  number | undefined
>();

// Class modifications can replace the helpers with matching signatures.
const changes = {
  _computeChange(
    previous: Report["prev_period"],
    current: number | string | undefined
  ) {
    return partial._computeChange(previous, current);
  },
  _userLabel(properties: Record<string, string>, row: ReportRow) {
    return partial._userLabel(properties, row);
  },
  valueAt(days: number) {
    return partial.valueAt(days);
  },
} satisfies Pick<Report, "_computeChange" | "_userLabel" | "valueAt">;
Report.reopen(changes);
