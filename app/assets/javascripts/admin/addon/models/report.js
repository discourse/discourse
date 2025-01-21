import EmberObject from "@ember/object";
import { isEmpty } from "@ember/utils";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
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
import I18n, { i18n } from "discourse-i18n";

// Change this line each time report format change
// and you want to ensure cache is reset
export const SCHEMA_VERSION = 4;

export default class Report extends EmberObject {
  static groupingForDatapoints(count) {
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

  static unitForDatapoints(count) {
    if (count >= DAILY_LIMIT_DAYS && count < WEEKLY_LIMIT_DAYS) {
      return "week";
    } else if (count >= WEEKLY_LIMIT_DAYS) {
      return "month";
    } else {
      return "day";
    }
  }

  static unitForGrouping(grouping) {
    switch (grouping) {
      case "monthly":
        return "month";
      case "weekly":
        return "week";
      default:
        return "day";
    }
  }

  static collapse(model, data, grouping) {
    grouping = grouping || Report.groupingForDatapoints(data.length);

    if (grouping === "daily") {
      return data;
    } else if (grouping === "weekly" || grouping === "monthly") {
      const isoKind = grouping === "weekly" ? "isoWeek" : "month";
      const kind = grouping === "weekly" ? "week" : "month";
      const startMoment = moment(model.start_date, "YYYY-MM-DD");

      let currentIndex = 0;
      let currentStart = startMoment.clone().startOf(isoKind);
      let currentEnd = startMoment.clone().endOf(isoKind);
      const transformedData = [
        {
          x: currentStart.format("YYYY-MM-DD"),
          y: 0,
        },
      ];

      let appliedAverage = false;
      data.forEach((d) => {
        const date = moment(d.x, "YYYY-MM-DD");

        if (
          !date.isSame(currentStart) &&
          !date.isBetween(currentStart, currentEnd)
        ) {
          if (model.average) {
            transformedData[currentIndex].y = applyAverage(
              transformedData[currentIndex].y,
              currentStart,
              currentEnd
            );

            appliedAverage = true;
          }

          currentIndex += 1;
          currentStart = currentStart.add(1, kind).startOf(isoKind);
          currentEnd = currentEnd.add(1, kind).endOf(isoKind);
        } else {
          appliedAverage = false;
        }

        if (transformedData[currentIndex]) {
          transformedData[currentIndex].y += d.y;
        } else {
          transformedData[currentIndex] = {
            x: d.x,
            y: d.y,
          };
        }
      });

      if (model.average && !appliedAverage) {
        transformedData[currentIndex].y = applyAverage(
          transformedData[currentIndex].y,
          currentStart,
          moment(model.end_date).subtract(1, "day") // remove 1 day as model end date is at 00:00 of next day
        );
      }

      return transformedData;
    }

    // ensure we return something if grouping is unknown
    return data;
  }

  static fillMissingDates(report, options = {}) {
    const dataField = options.dataField || "data";
    const filledField = options.filledField || "data";
    const startDate = options.startDate || "start_date";
    const endDate = options.endDate || "end_date";

    if (Array.isArray(report[dataField])) {
      const startDateFormatted = moment
        .utc(report[startDate])
        .locale("en")
        .format("YYYY-MM-DD");
      const endDateFormatted = moment
        .utc(report[endDate])
        .locale("en")
        .format("YYYY-MM-DD");

      if (
        report.modes[0] === "stacked_chart" ||
        report.modes[0] === "stacked_line_chart"
      ) {
        report[filledField] = report[dataField].map((rep) => {
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
        });
      } else if (report.modes[0] !== "radar") {
        report[filledField] = fillMissingDates(
          JSON.parse(JSON.stringify(report[dataField])),
          startDateFormatted,
          endDateFormatted
        );
      }
    }
  }

  static find(type, startDate, endDate, categoryId, groupId) {
    return ajax("/admin/reports/" + type, {
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
      model.setProperties(json.report);

      if (json.report.related_report) {
        // TODO: fillMissingDates if xaxis is date
        const related = Report.create({
          type: json.report.related_report.type,
        });
        related.setProperties(json.report.related_report);
        model.set("relatedReport", related);
      }

      return model;
    });
  }

  average = false;
  percent = false;
  higher_is_better = true;
  description_link = null;
  description = null;

  @discourseComputed("type", "start_date", "end_date")
  reportUrl(type, start_date, end_date) {
    start_date = moment.utc(start_date).locale("en").format("YYYY-MM-DD");

    end_date = moment.utc(end_date).locale("en").format("YYYY-MM-DD");

    return getURL(
      `/admin/reports/${type}?start_date=${start_date}&end_date=${end_date}`
    );
  }

  valueAt(numDaysAgo) {
    if (this.data) {
      const wantedDate = moment()
        .subtract(numDaysAgo, "days")
        .locale("en")
        .format("YYYY-MM-DD");
      const item = this.data.find((d) => d.x === wantedDate);
      if (item) {
        return item.y;
      }
    }
    return 0;
  }

  valueFor(startDaysAgo, endDaysAgo) {
    if (this.data) {
      const earliestDate = moment().subtract(endDaysAgo, "days").startOf("day");
      const latestDate = moment().subtract(startDaysAgo, "days").startOf("day");
      let d,
        sum = 0,
        count = 0;
      this.data.forEach((datum) => {
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

  @discourseComputed("data", "average")
  todayCount() {
    return this.valueAt(0);
  }

  @discourseComputed("data", "average")
  yesterdayCount() {
    return this.valueAt(1);
  }

  @discourseComputed("data", "average")
  sevenDaysAgoCount() {
    return this.valueAt(7);
  }

  @discourseComputed("data", "average")
  thirtyDaysAgoCount() {
    return this.valueAt(30);
  }

  @discourseComputed("data", "average")
  lastSevenDaysCount() {
    return this.averageCount(7, this.valueFor(1, 7));
  }

  @discourseComputed("data", "average")
  lastThirtyDaysCount() {
    return this.averageCount(30, this.valueFor(1, 30));
  }

  averageCount(count, value) {
    return this.average ? value / count : value;
  }

  @discourseComputed("yesterdayCount", "higher_is_better")
  yesterdayTrend(yesterdayCount, higherIsBetter) {
    return this._computeTrend(this.valueAt(2), yesterdayCount, higherIsBetter);
  }

  @discourseComputed("lastSevenDaysCount", "higher_is_better")
  sevenDaysTrend(lastSevenDaysCount, higherIsBetter) {
    return this._computeTrend(
      this.valueFor(8, 14),
      lastSevenDaysCount,
      higherIsBetter
    );
  }

  @discourseComputed("data")
  currentTotal(data) {
    return data.reduce((cur, pair) => cur + pair.y, 0);
  }

  @discourseComputed("data", "currentTotal")
  currentAverage(data, total) {
    return makeArray(data).length === 0
      ? 0
      : parseFloat((total / parseFloat(data.length)).toFixed(1));
  }

  @discourseComputed("trend", "higher_is_better")
  trendIcon(trend, higherIsBetter) {
    return this._iconForTrend(trend, higherIsBetter);
  }

  @discourseComputed("sevenDaysTrend", "higher_is_better")
  sevenDaysTrendIcon(sevenDaysTrend, higherIsBetter) {
    return this._iconForTrend(sevenDaysTrend, higherIsBetter);
  }

  @discourseComputed("thirtyDaysTrend", "higher_is_better")
  thirtyDaysTrendIcon(thirtyDaysTrend, higherIsBetter) {
    return this._iconForTrend(thirtyDaysTrend, higherIsBetter);
  }

  @discourseComputed("yesterdayTrend", "higher_is_better")
  yesterdayTrendIcon(yesterdayTrend, higherIsBetter) {
    return this._iconForTrend(yesterdayTrend, higherIsBetter);
  }

  @discourseComputed(
    "prev_period",
    "currentTotal",
    "currentAverage",
    "higher_is_better"
  )
  trend(prev, currentTotal, currentAverage, higherIsBetter) {
    const total = this.average ? currentAverage : currentTotal;
    return this._computeTrend(prev, total, higherIsBetter);
  }

  @discourseComputed(
    "prev30Days",
    "prev_period",
    "lastThirtyDaysCount",
    "higher_is_better"
  )
  thirtyDaysTrend(
    prev30Days,
    prev_period,
    lastThirtyDaysCount,
    higherIsBetter
  ) {
    return this._computeTrend(
      prev30Days ?? prev_period,
      lastThirtyDaysCount,
      higherIsBetter
    );
  }

  @discourseComputed("type")
  method(type) {
    if (type === "time_to_first_response") {
      return "average";
    } else {
      return "sum";
    }
  }

  percentChangeString(val1, val2) {
    const change = this._computeChange(val1, val2);

    if (isNaN(change) || !isFinite(change)) {
      return null;
    } else if (change > 0) {
      return `+${i18n("js.number.percent", { count: change.toFixed(0) })}`;
    } else {
      return `${i18n("js.number.percent", { count: change.toFixed(0) })}`;
    }
  }

  @discourseComputed("prev_period", "currentTotal", "currentAverage")
  trendTitle(prev, currentTotal, currentAverage) {
    let current = this.average ? currentAverage : currentTotal;
    let percent = this.percentChangeString(prev, current);

    if (this.average) {
      prev = prev ? prev.toFixed(1) : "0";
      if (this.percent) {
        current += "%";
        prev += "%";
      }
    } else {
      prev = number(prev);
      current = number(current);
    }

    return i18n("admin.dashboard.reports.trend_title", {
      percent,
      prev,
      current,
    });
  }

  changeTitle(valAtT1, valAtT2, prevPeriodString) {
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
          previousValue: number(valAtT1),
        }
      )
    );
    return title.join(" ");
  }

  @discourseComputed("yesterdayCount")
  yesterdayCountTitle(yesterdayCount) {
    return this.changeTitle(this.valueAt(2), yesterdayCount, "yesterday");
  }

  @discourseComputed("lastSevenDaysCount")
  sevenDaysCountTitle(lastSevenDaysCount) {
    return this.changeTitle(
      this.valueFor(8, 14),
      lastSevenDaysCount,
      "two_weeks_ago"
    );
  }

  @discourseComputed("prev30Days", "prev_period")
  canDisplayTrendIcon(prev30Days, prev_period) {
    return prev30Days ?? prev_period;
  }

  @discourseComputed("prev30Days", "prev_period", "lastThirtyDaysCount")
  thirtyDaysCountTitle(prev30Days, prev_period, lastThirtyDaysCount) {
    return this.changeTitle(
      prev30Days ?? prev_period,
      lastThirtyDaysCount,
      "thirty_days_ago"
    );
  }

  @discourseComputed("data")
  sortedData(data) {
    return this.xAxisIsDate ? data.toArray().reverse() : data.toArray();
  }

  @discourseComputed("data")
  xAxisIsDate() {
    if (!this.data[0]) {
      return false;
    }
    return this.data && this.data[0].x.match(/\d{4}-\d{1,2}-\d{1,2}/);
  }

  @discourseComputed("labels")
  computedLabels(labels) {
    return labels.map((label) => {
      const type = label.type || "string";

      let mainProperty;
      if (label.property) {
        mainProperty = label.property;
      } else if (type === "user") {
        mainProperty = label.properties["username"];
      } else if (type === "topic") {
        mainProperty = label.properties["title"];
      } else if (type === "post") {
        mainProperty = label.properties["truncated_raw"];
      } else {
        mainProperty = label.properties[0];
      }

      return {
        title: label.title,
        htmlTitle: label.html_title,
        sortProperty: label.sort_property || mainProperty,
        mainProperty,
        type,
        compute: (row, opts = {}) => {
          let value = null;

          if (opts.useSortProperty) {
            value = row[label.sort_property || mainProperty];
          } else {
            value = row[mainProperty];
          }

          if (type === "user") {
            return this._userLabel(label.properties, row);
          }
          if (type === "post") {
            return this._postLabel(label.properties, row);
          }
          if (type === "topic") {
            return this._topicLabel(label.properties, row);
          }
          if (type === "seconds") {
            return this._secondsLabel(value);
          }
          if (type === "link") {
            return this._linkLabel(label.properties, row);
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
            const date = moment(value);
            if (date.isValid()) {
              return this._dateLabel(value, date);
            }
          }
          if (type === "precise_date") {
            const date = moment(value);
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

  _userLabel(properties, row) {
    const username = row[properties.username];

    const formattedValue = () => {
      const userId = row[properties.id];

      const user = EmberObject.create({
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

  _topicLabel(properties, row) {
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

  _postLabel(properties, row) {
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

  _secondsLabel(value) {
    return {
      value: toNumber(value),
      formattedValue: durationTiny(value),
    };
  }

  _percentLabel(value) {
    return {
      value: toNumber(value),
      formattedValue: value ? `${value}%` : "—",
    };
  }

  _numberLabel(value, options = {}) {
    const formatNumbers = isEmpty(options.formatNumbers)
      ? true
      : options.formatNumbers;

    const formattedValue = () => (formatNumbers ? number(value) : value);

    return {
      value: toNumber(value),
      formattedValue: value ? formattedValue() : "—",
    };
  }

  _bytesLabel(value) {
    return {
      value: toNumber(value),
      formattedValue: I18n.toHumanSize(value),
    };
  }

  _dateLabel(value, date, format = "LL") {
    return {
      value,
      formattedValue: value ? date.format(format) : "—",
    };
  }

  _textLabel(value) {
    const escaped = escapeExpression(value);

    return {
      value,
      formattedValue: value ? escaped : "—",
    };
  }

  _linkLabel(properties, row) {
    const property = properties[0];
    const value = getURL(row[property]);
    const formattedValue = (href, anchor) => {
      return `<a href="${escapeExpression(href)}">${escapeExpression(
        anchor
      )}</a>`;
    };

    return {
      value,
      formattedValue: value ? formattedValue(value, row[properties[1]]) : "—",
    };
  }

  _computeChange(valAtT1, valAtT2) {
    return ((valAtT2 - valAtT1) / valAtT1) * 100;
  }

  _computeTrend(valAtT1, valAtT2, higherIsBetter) {
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

  _iconForTrend(trend, higherIsBetter) {
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

export const WEEKLY_LIMIT_DAYS = 365;
export const DAILY_LIMIT_DAYS = 34;

function applyAverage(value, start, end) {
  const count = end.diff(start, "day") + 1; // 1 to include start
  return parseFloat((value / count).toFixed(2));
}
