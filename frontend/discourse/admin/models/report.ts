/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import EmberObject, { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import type { Moment, MomentInput } from "moment";
import { REPORT_MODES } from "discourse/admin/lib/constants";
import { ajax } from "discourse/lib/ajax";
import { durationTiny, number } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { makeArray } from "discourse/lib/helpers";
import round from "discourse/lib/round";
import {
  escapeExpression,
  fillMissingDates,
  formatUsername,
  toNumber,
} from "discourse/lib/utilities";
import { renderAvatar } from "discourse/ui-kit/helpers/d-user-avatar";
import I18n, { i18n } from "discourse-i18n";

/** Change when the report format changes and cached reports must be reset. */
export const SCHEMA_VERSION = 5 as const;

/** Table keys are supplied by column descriptors; SQL decimals can be strings. */
export type ReportCellValue = string | number | boolean | null | undefined;
export type ReportRow = Record<string, ReportCellValue>;

export interface ReportPoint {
  x: string;
  y: number;
  end_date?: string;
}

export interface ReportSeries {
  req?: string;
  label: string;
  color: string;
  data: ReportPoint[];
}

export interface ReportStorageStats {
  backups: {
    used_bytes: number;
    free_bytes: number | null;
    count: number;
    last_backup_taken_at: string | null;
  } | null;
  uploads: { used_bytes: number; free_bytes: number | null };
}

export type ReportData =
  | ReportPoint[]
  | ReportSeries[]
  | ReportRow[]
  | ReportStorageStats
  | null;
export type ReportComparison = number | ReportRow | ReportRow[] | null;
export type ReportGrouping = "daily" | "weekly" | "monthly";
export type ReportTrend =
  | "high-trending-up"
  | "high-trending-down"
  | "trending-up"
  | "trending-down"
  | "no-change";
export type ReportTrendIcon =
  | "angle-up"
  | "angle-down"
  | "angles-up"
  | "angles-down"
  | "minus";

/** Semantic names (or link positions) map to keys in a table row. */
export type ReportLabelProperties = Record<string, string> | string[];
export interface ReportLabel {
  title: string;
  html_title?: string;
  type?: string;
  property?: string;
  properties?: ReportLabelProperties;
  sort_property?: string;
}

export interface ReportCellOptions {
  useSortProperty?: boolean;
  formatNumbers?: boolean;
}

/** Table consumers may add the descriptor's type and property to a computed cell. */
export interface ReportCell {
  value: ReportCellValue;
  formattedValue: ReportCellValue;
  type?: string;
  property?: string;
}

export interface ReportComputedLabel {
  title: string;
  htmlTitle?: string;
  mainProperty: string;
  sortProperty: string;
  type: string;
  compute: (row: ReportRow, options?: ReportCellOptions) => ReportCell;
}

export interface ReportFilter {
  id: string;
  type: string;
  default?: ReportCellValue | string[] | number[];
  choices?: (string | { id: string | number; name: string })[];
  allow_any?: boolean;
  auto_insert_none_item?: boolean;
  disabled?: boolean;
}

/** Related-item renderers interpret their own JSON, including nested plugin payloads. */
export type ReportRelatedValue =
  | string
  | number
  | boolean
  | null
  | ReportRelatedValue[]
  | { [key: string]: ReportRelatedValue };

/** Full endpoint view and client state. */
export interface ReportFields {
  type: string;
  title: string | null;
  xaxis: string | Record<string, string> | null;
  yaxis: string | null;
  data: ReportData;
  start_date: string;
  end_date: string;
  prev_start_date: string;
  prev_end_date: string;
  prev_data: ReportPoint[] | ReportSeries[] | null;
  prev30Days: number | ReportRow[] | null;
  prev_period?: ReportComparison;
  dates_filtering: boolean;
  report_key: string;
  primary_color: string;
  secondary_color: string;
  available_filters: ReportFilter[];
  labels: ReportLabel[] | string[];
  modes: string[];
  legacy?: boolean;
  icon?: string;
  error?: "not_found" | "timeout" | "exception" | null;
  total?: number | string;
  limit?: number;
  default_group_by?: string;
  y_axis_title?: string;
  related_items?: Record<string, ReportRelatedValue[]>;
  related_items_totals?: Record<string, number>;
  related_report?: ReportPayload | null;
  relatedReport?: Report;
  chartData?: ReportPoint[] | ReportSeries[];
  prevChartData?: ReportPoint[] | ReportSeries[];
  empty?: boolean;
}

/** Full endpoint JSON without Ember methods or computed properties. */
export type ReportPayload = ReportFields &
  Pick<
    Report,
    | "average"
    | "percent"
    | "higher_is_better"
    | "description"
    | "description_link"
  >;
export type ReportCreateAttrs<M extends EmberObject = Report> = Partial<M>;

/** Property names to read/write, rather than date values. */
export interface ReportFillOptions {
  dataField?: string;
  filledField?: string;
  startDate?: string;
  endDate?: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Report extends ReportFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Report extends EmberObject {
  /** Inherited factory; find initially creates only type, and tests may supply only data. */
  declare static create: <C extends typeof EmberObject>(
    this: C,
    ...args: ReportCreateAttrs<InstanceType<C>>[]
  ) => InstanceType<C>;

  static groupingForDatapoints(count: number): ReportGrouping | undefined {
    if (count < DAILY_LIMIT_DAYS) {
      return "daily";
    }

    if (count >= DAILY_LIMIT_DAYS && count < WEEKLY_LIMIT_DAYS) {
      return "weekly";
    }

    if (count >= WEEKLY_LIMIT_DAYS) {
      return "monthly";
    }
  }

  static unitForDatapoints(count: number): "day" | "week" | "month" {
    if (count >= DAILY_LIMIT_DAYS && count < WEEKLY_LIMIT_DAYS) {
      return "week";
    } else if (count >= WEEKLY_LIMIT_DAYS) {
      return "month";
    } else {
      return "day";
    }
  }

  static unitForGrouping(
    grouping: string | undefined
  ): "day" | "week" | "month" {
    switch (grouping) {
      case "monthly":
        return "month";
      case "weekly":
        return "week";
      default:
        return "day";
    }
  }

  static collapse(
    model: {
      start_date: MomentInput;
      end_date: MomentInput;
      average?: boolean;
    },
    data: ReportPoint[],
    grouping?: string
  ): ReportPoint[];

  static collapse(
    model: {
      start_date: MomentInput;
      end_date: MomentInput;
      average?: boolean;
    },
    data: ReportPoint[],
    grouping: string | undefined
  ): ReportPoint[] {
    grouping = grouping || Report.groupingForDatapoints(data.length);

    if (grouping === "daily") {
      return data;
    } else if (grouping === "weekly" || grouping === "monthly") {
      const isoKind = grouping === "weekly" ? "isoWeek" : "month";
      const kind = grouping === "weekly" ? "week" : "month";
      const selectedStart = Report.#dateMoment(model.start_date);
      const selectedEnd = Report.#dateMoment(model.end_date);

      let currentIndex = 0;
      let currentStart = selectedStart.clone().startOf(isoKind);
      let currentEnd = selectedStart.clone().endOf(isoKind);
      const bucketStart = () => moment.max(currentStart, selectedStart);
      const bucketEnd = () => moment.min(currentEnd, selectedEnd);
      const bucket = () => ({
        x: bucketStart().format("YYYY-MM-DD"),
        y: 0,
        end_date: bucketEnd().format("YYYY-MM-DD"),
      });
      const transformedData = [bucket()];

      let appliedAverage = false;
      data.forEach((d) => {
        const date = Report.#dateMoment(d.x);

        while (date.isAfter(currentEnd)) {
          if (model.average) {
            transformedData[currentIndex].y = applyAverage(
              transformedData[currentIndex].y,
              bucketStart(),
              bucketEnd()
            );

            appliedAverage = true;
          }

          currentIndex += 1;
          currentStart = currentStart.add(1, kind).startOf(isoKind);
          currentEnd = currentEnd.add(1, kind).endOf(isoKind);
          transformedData[currentIndex] = bucket();
        }

        transformedData[currentIndex].y += d.y;
        appliedAverage = false;
      });

      if (model.average && !appliedAverage) {
        transformedData[currentIndex].y = applyAverage(
          transformedData[currentIndex].y,
          bucketStart(),
          bucketEnd()
        );
      }

      return transformedData;
    }

    // ensure we return something if grouping is unknown
    return data;
  }

  static fillMissingDates<T extends { modes: string[] }>(
    report: T,
    options?: ReportFillOptions
  ): void;

  static fillMissingDates(
    report: { modes: string[]; [key: string]: unknown },
    options: ReportFillOptions = {}
  ): void {
    const dataField = options.dataField || "data";
    const filledField = options.filledField || "data";
    const startDate = options.startDate || "start_date";
    const endDate = options.endDate || "end_date";

    if (Array.isArray(report[dataField])) {
      const startDateFormatted = moment
        .utc(report[startDate] as MomentInput)
        .locale("en")
        .format("YYYY-MM-DD");
      const endDateFormatted = moment
        .utc(report[endDate] as MomentInput)
        .locale("en")
        .format("YYYY-MM-DD");

      if (
        report.modes[0] === "stacked_chart" ||
        report.modes[0] === "stacked_line_chart"
      ) {
        report[filledField] = (report[dataField] as ReportSeries[]).map(
          (rep) => {
            return {
              req: rep.req,
              label: rep.label,
              color: rep.color,
              data: fillMissingDates(
                JSON.parse(JSON.stringify(rep.data)),
                startDateFormatted,
                endDateFormatted
              ),
            };
          }
        );
      } else if (report.modes[0] !== "radar") {
        report[filledField] = fillMissingDates(
          JSON.parse(JSON.stringify(report[dataField])),
          startDateFormatted,
          endDateFormatted
        );
      }
    }
  }

  static find(
    type: string,
    startDate: string,
    endDate: string,
    categoryId?: number,
    groupId?: number
  ): Promise<Report>;

  static find(
    type: string,
    startDate: string,
    endDate: string,
    categoryId: number | undefined,
    groupId: number | undefined
  ): Promise<Report> {
    return ajax<{ report: ReportPayload }>("/admin/reports/" + type, {
      data: {
        start_date: startDate,
        end_date: endDate,
        category_id: categoryId,
        group_id: groupId,
      },
    }).then((json) => {
      // don’t fill for large multi column tables
      // which are not date based
      const modes = json.report.modes;
      if (modes.length !== 1 && modes[0] !== "table") {
        Report.fillMissingDates(json.report);
      }

      const model = Report.create({ type });
      model.setProperties<keyof ReportPayload, ReportPayload>(json.report);

      if (json.report.related_report) {
        // TODO: fillMissingDates if xaxis is date
        const related = Report.create({
          type: json.report.related_report.type,
        });
        related.setProperties<keyof ReportPayload, ReportPayload>(
          json.report.related_report
        );
        model.set("relatedReport", related);
      }

      return model;
    });
  }

  static #dateMoment(value: MomentInput): Moment {
    if (moment.isMoment(value)) {
      return value.clone().startOf("day");
    }

    if (value instanceof Date) {
      return moment(value).startOf("day");
    }

    return moment.utc(value).startOf("day");
  }

  /** Forwarded to the avatar renderer, but nothing assigns it on reports. */
  declare siteSettings?: unknown;

  average = false;
  percent = false;
  higher_is_better = true;

  description_link: string | null = null;

  description: string | null = null;

  @computed("type", "start_date", "end_date")
  get reportUrl(): string {
    const start_date = moment
      .utc(this.start_date)
      .locale("en")
      .format("YYYY-MM-DD");

    const end_date = moment
      .utc(this.end_date)
      .locale("en")
      .format("YYYY-MM-DD");

    return getURL(
      `/admin/reports/${this.type}?start_date=${start_date}&end_date=${end_date}`
    );
  }

  /** Only stacked-chart mode is flattened; other modes retain their original data shape. */
  get combinedData(): ReportData {
    if (this.modes?.includes(REPORT_MODES.stacked_chart)) {
      return Object.values(
        (this.data as ReportSeries[])
          .flatMap((series) => series.data)
          .reduce(
            (acc, { x, y }) => {
              acc[x] ??= { x, y: 0 };
              acc[x].y += y;
              return acc;
            },
            {} as Record<string, ReportPoint>
          )
      );
    }
    return this.data;
  }

  @computed("data", "average")
  get todayCount() {
    return this.valueAt(0);
  }

  @computed("data", "average")
  get yesterdayCount() {
    return this.valueAt(1);
  }

  @computed("data", "average")
  get sevenDaysAgoCount() {
    return this.valueAt(7);
  }

  @computed("data", "average")
  get thirtyDaysAgoCount() {
    return this.valueAt(30);
  }

  @computed("data", "average")
  get lastSevenDaysCount() {
    return this.averageCount(7, this.valueFor(1, 7));
  }

  @computed("data", "average")
  get lastThirtyDaysCount() {
    return this.averageCount(30, this.valueFor(1, 30));
  }

  @computed("yesterdayCount", "higher_is_better")
  get yesterdayTrend() {
    return this._computeTrend(
      this.valueAt(2),
      this.yesterdayCount,
      this.higher_is_better
    );
  }

  @computed("lastSevenDaysCount", "higher_is_better")
  get sevenDaysTrend() {
    return this._computeTrend(
      this.valueFor(8, 14),
      this.lastSevenDaysCount,
      this.higher_is_better
    );
  }

  /** Flat numeric points are assumed here, even though other report modes carry different data. */
  @computed("data")
  get currentTotal() {
    return (this.data as ReportPoint[]).reduce((cur, pair) => cur + pair.y, 0);
  }

  /** Keeps the original parseFloat coercion of the point count. */
  @computed("data", "currentTotal")
  get currentAverage() {
    return makeArray<ReportData>(this.data).length === 0
      ? 0
      : parseFloat(
          (
            this.currentTotal /
            parseFloat((this.data as ReportPoint[]).length as unknown as string)
          ).toFixed(1)
        );
  }

  @computed("trend", "higher_is_better")
  get trendIcon() {
    return this._iconForTrend(this.trend, this.higher_is_better);
  }

  @computed("sevenDaysTrend", "higher_is_better")
  get sevenDaysTrendIcon() {
    return this._iconForTrend(this.sevenDaysTrend, this.higher_is_better);
  }

  @computed("thirtyDaysTrend", "higher_is_better")
  get thirtyDaysTrendIcon() {
    return this._iconForTrend(this.thirtyDaysTrend, this.higher_is_better);
  }

  @computed("yesterdayTrend", "higher_is_better")
  get yesterdayTrendIcon() {
    return this._iconForTrend(this.yesterdayTrend, this.higher_is_better);
  }

  @computed("prev_period", "currentTotal", "currentAverage", "higher_is_better")
  get trend() {
    const total = this.average ? this.currentAverage : this.currentTotal;
    return this._computeTrend(this.prev_period, total, this.higher_is_better);
  }

  @computed(
    "prev30Days",
    "prev_period",
    "lastThirtyDaysCount",
    "higher_is_better"
  )
  get thirtyDaysTrend() {
    return this._computeTrend(
      this.prev30Days ?? this.prev_period,
      this.lastThirtyDaysCount,
      this.higher_is_better
    );
  }

  @computed("type")
  get method(): "average" | "sum" {
    if (this.type === "time_to_first_response") {
      return "average";
    } else {
      return "sum";
    }
  }

  /** Average-mode formatting assumes a numeric comparison, without validating other producer shapes. */
  @computed("prev_period", "currentTotal", "currentAverage")
  get trendTitle(): string {
    let prev: number | string | null | undefined = this.prev_period as
      | number
      | null
      | undefined;
    let current: number | string = this.average
      ? this.currentAverage
      : this.currentTotal;
    let percent = this.percentChangeString(prev, current);

    if (this.average) {
      prev = prev ? (prev as number).toFixed(1) : "0";
      if (this.percent) {
        (current as number | string) += "%";
        prev += "%";
      }
    } else {
      // TODO(typescript-pending): formatter.number's inferred signature requires optional options; remove casts when typed.
      prev = (number as (value: unknown) => string)(prev);
      current = (number as (value: unknown) => string)(current);
    }

    return i18n("admin.dashboard.reports.trend_title", {
      percent,
      prev,
      current,
    });
  }

  @computed("yesterdayCount")
  get yesterdayCountTitle() {
    return this.changeTitle(this.valueAt(2), this.yesterdayCount, "yesterday");
  }

  @computed("lastSevenDaysCount")
  get sevenDaysCountTitle() {
    return this.changeTitle(
      this.valueFor(8, 14),
      this.lastSevenDaysCount,
      "two_weeks_ago"
    );
  }

  /** Returns the comparison value itself, including zero, null, or an omitted period. */
  @computed("prev30Days", "prev_period")
  get canDisplayTrendIcon() {
    return this.prev30Days ?? this.prev_period;
  }

  @computed("prev30Days", "prev_period", "lastThirtyDaysCount")
  get thirtyDaysCountTitle() {
    return this.changeTitle(
      this.prev30Days ?? this.prev_period,
      this.lastThirtyDaysCount,
      "thirty_days_ago"
    );
  }

  /** Array modes only; storage data and null are not iterable. */
  @computed("data")
  get sortedData(): (ReportPoint | ReportSeries | ReportRow)[] {
    return this.xAxisIsDate
      ? [
          ...(this.data as Exclude<ReportData, ReportStorageStats | null>),
        ].reverse()
      : [...(this.data as Exclude<ReportData, ReportStorageStats | null>)];
  }

  /** Assumes flat string-x points and returns the match result, rather than a boolean. */
  @computed("data")
  get xAxisIsDate(): false | RegExpMatchArray | null {
    if (!(this.data as ReportPoint[])[0]) {
      return false;
    }
    return (
      this.data &&
      (this.data as ReportPoint[])[0].x.match(/\d{4}-\d{1,2}-\d{1,2}/)
    );
  }

  /** Table mode assumes descriptors; plugin string labels are consumed by their custom renderers. */
  @computed("labels")
  get computedLabels(): ReportComputedLabel[] {
    // Descriptor types select semantic keys; the wire format does not enforce their correlation.
    return (this.labels as ReportLabel[]).map((label) => {
      const type = label.type || "string";

      let mainProperty;
      if (label.property) {
        mainProperty = label.property;
      } else if (type === "user") {
        mainProperty = (label.properties as Record<string, string>)["username"];
      } else if (type === "topic") {
        mainProperty = (label.properties as Record<string, string>)["title"];
      } else if (type === "post") {
        mainProperty = (label.properties as Record<string, string>)[
          "truncated_raw"
        ];
      } else {
        mainProperty = (label.properties as string[])[0];
      }

      return {
        title: label.title,
        htmlTitle: label.html_title,
        sortProperty: label.sort_property || mainProperty,
        mainProperty,
        type,
        compute: (row: ReportRow, opts: ReportCellOptions = {}): ReportCell => {
          let value;

          if (opts.useSortProperty) {
            value = row[label.sort_property || mainProperty];
          } else {
            value = row[mainProperty];
          }

          if (type === "user") {
            return this._userLabel(
              label.properties as Record<string, string>,
              row
            );
          }
          if (type === "post") {
            return this._postLabel(
              label.properties as Record<string, string>,
              row
            );
          }
          if (type === "topic") {
            return this._topicLabel(
              label.properties as Record<string, string>,
              row
            );
          }
          if (type === "seconds") {
            return this._secondsLabel(value);
          }
          if (type === "link") {
            return this._linkLabel(label.properties as string[], row);
          }
          if (type === "percent") {
            return this._percentLabel(value);
          }
          if (type === "bytes") {
            return this._bytesLabel(value);
          }
          if (type === "number") {
            return this._numberLabel(value, opts);
          }
          if (type === "date") {
            const date = moment(value as MomentInput);
            if (date.isValid()) {
              return this._dateLabel(value, date);
            }
          }
          if (type === "precise_date") {
            const date = moment(value as MomentInput);
            if (date.isValid()) {
              return this._dateLabel(value, date, "LLL");
            }
          }
          if (type === "text") {
            return this._textLabel(value);
          }

          return {
            value,
            type,
            property: mainProperty,
            formattedValue: value ? escapeExpression(value) : "—",
          };
        },
      };
    });
  }

  /** Count helpers assume combinedData is a flat numeric time series. */
  valueAt(numDaysAgo: number): number {
    if (this.combinedData) {
      const wantedDate = moment()
        .subtract(numDaysAgo, "days")
        .locale("en")
        .format("YYYY-MM-DD");
      const item = (this.combinedData as ReportPoint[]).find(
        (d) => d.x === wantedDate
      );
      if (item) {
        return item.y;
      }
    }
    return 0;
  }

  /** Returns undefined when data is absent, including on partially constructed reports. */
  valueFor(startDaysAgo: number, endDaysAgo: number): number | undefined {
    if (this.combinedData) {
      const earliestDate = moment().subtract(endDaysAgo, "days").startOf("day");
      const latestDate = moment().subtract(startDaysAgo, "days").startOf("day");
      let d: Moment,
        sum = 0,
        count = 0;
      (this.combinedData as ReportPoint[]).forEach((datum) => {
        d = moment(datum.x);
        if (d >= earliestDate && d <= latestDate) {
          sum += datum.y;
          count++;
        }
      });
      if (this.method === "average" && count > 0) {
        sum /= count;
      }
      return round(sum, -2);
    }
  }

  /** Undefined is passed through, or coerced to NaN by division for average reports. */
  averageCount(count: number, value: number | undefined): number | undefined {
    return this.average ? (value as number) / count : value;
  }

  percentChangeString(
    val1: ReportComparison | undefined,
    val2: number | string | undefined
  ): string | null {
    const change = this._computeChange(val1, val2);

    if (isNaN(change) || !isFinite(change)) {
      return null;
    } else if (change > 0) {
      return `+${i18n("js.number.percent", { count: change.toFixed(0) })}`;
    } else {
      return `${i18n("js.number.percent", { count: change.toFixed(0) })}`;
    }
  }

  changeTitle(
    valAtT1: ReportComparison | undefined,
    valAtT2: number | undefined,
    prevPeriodString: string
  ): string {
    const change = this.percentChangeString(valAtT1, valAtT2);
    const title = [];
    if (change) {
      title.push(
        i18n("admin.dashboard.reports.percent_change_tooltip", {
          percent: change,
        })
      );
    }
    title.push(
      i18n(
        `admin.dashboard.reports.percent_change_tooltip_previous_value.${prevPeriodString}`,
        {
          count: valAtT1,
          // TODO(typescript-pending): remove when formatter.number types its optional options.
          previousValue: (number as (value: unknown) => string)(valAtT1),
        }
      )
    );
    return title.join(" ");
  }

  _userLabel(properties: Record<string, string>, row: ReportRow): ReportCell {
    const username = row[properties.username];

    const formattedValue = () => {
      const userId = row[properties.id];

      // EmberObject.create only accepts declared members, and this anonymous record declares none.
      const user = (
        EmberObject.create as (attrs: {
          username: ReportCellValue;
          name: string;
          avatar_template: ReportCellValue;
        }) => EmberObject & { name: string }
      )({
        username,
        name: formatUsername(username),
        avatar_template: row[properties.avatar],
      });

      const href = getURL(`/admin/users/${userId}/${username}`);

      const avatarImg = renderAvatar(user, {
        imageSize: "tiny",
        ignoreTitle: true,
        siteSettings: this.siteSettings,
      });

      return `<a href='${href}'>${avatarImg}<span class='username'>${user.name}</span></a>`;
    };

    return {
      value: username,
      formattedValue: username ? formattedValue() : "—",
    };
  }

  _topicLabel(properties: Record<string, string>, row: ReportRow): ReportCell {
    const topicTitle = row[properties.title];

    const formattedValue = () => {
      const topicId = row[properties.id];
      const href = getURL(`/t/-/${topicId}`);
      return `<a href='${href}'>${escapeExpression(topicTitle)}</a>`;
    };

    return {
      value: topicTitle,
      formattedValue: topicTitle ? formattedValue() : "—",
    };
  }

  _postLabel(properties: Record<string, string>, row: ReportRow): ReportCell {
    const postTitle = row[properties.truncated_raw];
    const postNumber = row[properties.number];
    const topicId = row[properties.topic_id];
    const href = getURL(`/t/-/${topicId}/${postNumber}`);

    return {
      property: properties.title,
      value: postTitle,
      formattedValue:
        postTitle && href
          ? `<a href='${href}'>${escapeExpression(postTitle)}</a>`
          : "—",
    };
  }

  _secondsLabel(value: ReportCellValue): ReportCell {
    return {
      value: toNumber(value),
      // TODO(typescript-pending): remove when durationTiny types its optional options.
      formattedValue: (durationTiny as (value: ReportCellValue) => string)(
        value
      ),
    };
  }

  _percentLabel(value: ReportCellValue): ReportCell {
    return {
      value: toNumber(value),
      formattedValue: value === null || value === undefined ? "—" : `${value}%`,
    };
  }

  _numberLabel(
    value: ReportCellValue,
    options: ReportCellOptions = {}
  ): ReportCell {
    const formatNumbers = isEmpty(options.formatNumbers)
      ? true
      : options.formatNumbers;

    const formattedValue = () =>
      formatNumbers ? I18n.toNumber(value, { precision: 0 }) : value;

    return {
      value: toNumber(value),
      formattedValue: value ? formattedValue() : "—",
    };
  }

  _bytesLabel(value: ReportCellValue): ReportCell {
    return {
      value: toNumber(value),
      // TODO(typescript-pending): remove when toHumanSize publishes its optional options and string return.
      formattedValue: (I18n.toHumanSize as (value: ReportCellValue) => string)(
        value
      ),
    };
  }

  _dateLabel(value: ReportCellValue, date: Moment, format = "LL"): ReportCell {
    return {
      value,
      formattedValue: value ? date.format(format) : "—",
    };
  }

  _textLabel(value: ReportCellValue): ReportCell {
    const escaped = escapeExpression(value);

    return {
      value,
      formattedValue: value ? escaped : "—",
    };
  }

  _linkLabel(properties: string[], row: ReportRow): ReportCell {
    const property = properties[0];
    const value = getURL(row[property] as string);
    const formattedValue = (href: string, anchor: ReportCellValue) => {
      return `<a href="${escapeExpression(href)}">${escapeExpression(
        anchor
      )}</a>`;
    };

    return {
      value,
      formattedValue: value ? formattedValue(value, row[properties[1]]) : "—",
    };
  }

  /** Preserves arithmetic coercion of nullable, object, and row-valued comparisons. */
  _computeChange(
    valAtT1: ReportComparison | undefined,
    valAtT2: number | string | undefined
  ): number {
    return (
      (((valAtT2 as number) - (valAtT1 as number)) / (valAtT1 as number)) * 100
    );
  }

  _computeTrend(
    valAtT1: ReportComparison | undefined,
    valAtT2: number | undefined,
    higherIsBetter: boolean
  ): ReportTrend | undefined {
    const change = this._computeChange(valAtT1, valAtT2);

    if (change > 50) {
      return higherIsBetter ? "high-trending-up" : "high-trending-down";
    } else if (change > 2) {
      return higherIsBetter ? "trending-up" : "trending-down";
    } else if (change <= 2 && change >= -2) {
      return "no-change";
    } else if (change < -50) {
      return higherIsBetter ? "high-trending-down" : "high-trending-up";
    } else if (change < -2) {
      return higherIsBetter ? "trending-down" : "trending-up";
    }
  }

  _iconForTrend(
    trend: ReportTrend | undefined,
    higherIsBetter: boolean
  ): ReportTrendIcon {
    switch (trend) {
      case "trending-up":
        return higherIsBetter ? "angle-up" : "angle-down";
      case "trending-down":
        return higherIsBetter ? "angle-down" : "angle-up";
      case "high-trending-up":
        return higherIsBetter ? "angles-up" : "angles-down";
      case "high-trending-down":
        return higherIsBetter ? "angles-down" : "angles-up";
      default:
        return "minus";
    }
  }
}

export const WEEKLY_LIMIT_DAYS = 365 as const;
export const DAILY_LIMIT_DAYS = 34 as const;

function applyAverage(value: number, start: Moment, end: Moment): number {
  const count = end.diff(start, "day") + 1; // 1 to include start
  return parseFloat((value / count).toFixed(2));
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");
