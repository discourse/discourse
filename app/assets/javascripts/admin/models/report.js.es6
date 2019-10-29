import EmberObject from "@ember/object";
import { escapeExpression } from "discourse/lib/utilities";
import { ajax } from "discourse/lib/ajax";
import round from "discourse/lib/round";
import {
  fillMissingDates,
  formatUsername,
  toNumber
} from "discourse/lib/utilities";
import computed from "ember-addons/ember-computed-decorators";
import { number, durationTiny } from "discourse/lib/formatter";
import { renderAvatar } from "discourse/helpers/user-avatar";

// Change this line each time report format change
// and you want to ensure cache is reset
export const SCHEMA_VERSION = 4;

const Report = Discourse.Model.extend({
  average: false,
  percent: false,
  higher_is_better: true,

  @computed("modes")
  isTable(modes) {
    return modes.some(mode => mode === "table");
  },

  @computed("type", "start_date", "end_date")
  reportUrl(type, start_date, end_date) {
    start_date = moment
      .utc(start_date)
      .locale("en")
      .format("YYYY-MM-DD");

    end_date = moment
      .utc(end_date)
      .locale("en")
      .format("YYYY-MM-DD");

    return Discourse.getURL(
      `/admin/reports/${type}?start_date=${start_date}&end_date=${end_date}`
    );
  },

  valueAt(numDaysAgo) {
    if (this.data) {
      const wantedDate = moment()
        .subtract(numDaysAgo, "days")
        .locale("en")
        .format("YYYY-MM-DD");
      const item = this.data.find(d => d.x === wantedDate);
      if (item) {
        return item.y;
      }
    }
    return 0;
  },

  valueFor(startDaysAgo, endDaysAgo) {
    if (this.data) {
      const earliestDate = moment()
        .subtract(endDaysAgo, "days")
        .startOf("day");
      const latestDate = moment()
        .subtract(startDaysAgo, "days")
        .startOf("day");
      let d,
        sum = 0,
        count = 0;
      this.data.forEach(datum => {
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
  },

  @computed("data", "average")
  todayCount() {
    return this.valueAt(0);
  },

  @computed("data", "average")
  yesterdayCount() {
    return this.valueAt(1);
  },

  @computed("data", "average")
  sevenDaysAgoCount() {
    return this.valueAt(7);
  },

  @computed("data", "average")
  thirtyDaysAgoCount() {
    return this.valueAt(30);
  },

  @computed("data", "average")
  lastSevenDaysCount() {
    return this.averageCount(7, this.valueFor(1, 7));
  },

  @computed("data", "average")
  lastThirtyDaysCount() {
    return this.averageCount(30, this.valueFor(1, 30));
  },

  averageCount(count, value) {
    return this.average ? value / count : value;
  },

  @computed("yesterdayCount", "higher_is_better")
  yesterdayTrend(yesterdayCount, higherIsBetter) {
    return this._computeTrend(this.valueAt(2), yesterdayCount, higherIsBetter);
  },

  @computed("lastSevenDaysCount", "higher_is_better")
  sevenDaysTrend(lastSevenDaysCount, higherIsBetter) {
    return this._computeTrend(
      this.valueFor(8, 14),
      lastSevenDaysCount,
      higherIsBetter
    );
  },

  @computed("data")
  currentTotal(data) {
    return data.reduce((cur, pair) => cur + pair.y, 0);
  },

  @computed("data", "currentTotal")
  currentAverage(data, total) {
    return Ember.makeArray(data).length === 0
      ? 0
      : parseFloat((total / parseFloat(data.length)).toFixed(1));
  },

  @computed("trend", "higher_is_better")
  trendIcon(trend, higherIsBetter) {
    return this._iconForTrend(trend, higherIsBetter);
  },

  @computed("sevenDaysTrend", "higher_is_better")
  sevenDaysTrendIcon(sevenDaysTrend, higherIsBetter) {
    return this._iconForTrend(sevenDaysTrend, higherIsBetter);
  },

  @computed("thirtyDaysTrend", "higher_is_better")
  thirtyDaysTrendIcon(thirtyDaysTrend, higherIsBetter) {
    return this._iconForTrend(thirtyDaysTrend, higherIsBetter);
  },

  @computed("yesterdayTrend", "higher_is_better")
  yesterdayTrendIcon(yesterdayTrend, higherIsBetter) {
    return this._iconForTrend(yesterdayTrend, higherIsBetter);
  },

  @computed("prev_period", "currentTotal", "currentAverage", "higher_is_better")
  trend(prev, currentTotal, currentAverage, higherIsBetter) {
    const total = this.average ? currentAverage : currentTotal;
    return this._computeTrend(prev, total, higherIsBetter);
  },

  @computed("prev30Days", "lastThirtyDaysCount", "higher_is_better")
  thirtyDaysTrend(prev30Days, lastThirtyDaysCount, higherIsBetter) {
    return this._computeTrend(prev30Days, lastThirtyDaysCount, higherIsBetter);
  },

  @computed("type")
  method(type) {
    if (type === "time_to_first_response") {
      return "average";
    } else {
      return "sum";
    }
  },

  percentChangeString(val1, val2) {
    const change = this._computeChange(val1, val2);

    if (isNaN(change) || !isFinite(change)) {
      return null;
    } else if (change > 0) {
      return "+" + change.toFixed(0) + "%";
    } else {
      return change.toFixed(0) + "%";
    }
  },

  @computed("prev_period", "currentTotal", "currentAverage")
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

    return I18n.t("admin.dashboard.reports.trend_title", {
      percent,
      prev,
      current
    });
  },

  changeTitle(valAtT1, valAtT2, prevPeriodString) {
    const change = this.percentChangeString(valAtT1, valAtT2);
    let title = "";
    if (change) {
      title += `${change} change. `;
    }
    title += `Was ${number(valAtT1)} ${prevPeriodString}.`;
    return title;
  },

  @computed("yesterdayCount")
  yesterdayCountTitle(yesterdayCount) {
    return this.changeTitle(this.valueAt(2), yesterdayCount, "two days ago");
  },

  @computed("lastSevenDaysCount")
  sevenDaysCountTitle(lastSevenDaysCount) {
    return this.changeTitle(
      this.valueFor(8, 14),
      lastSevenDaysCount,
      "two weeks ago"
    );
  },

  @computed("prev30Days", "lastThirtyDaysCount")
  thirtyDaysCountTitle(prev30Days, lastThirtyDaysCount) {
    return this.changeTitle(
      prev30Days,
      lastThirtyDaysCount,
      "in the previous 30 day period"
    );
  },

  @computed("data")
  sortedData(data) {
    return this.xAxisIsDate ? data.toArray().reverse() : data.toArray();
  },

  @computed("data")
  xAxisIsDate() {
    if (!this.data[0]) return false;
    return this.data && this.data[0].x.match(/\d{4}-\d{1,2}-\d{1,2}/);
  },

  @computed("labels")
  computedLabels(labels) {
    return labels.map(label => {
      const type = label.type || "string";

      let mainProperty;
      if (label.property) mainProperty = label.property;
      else if (type === "user") mainProperty = label.properties["username"];
      else if (type === "topic") mainProperty = label.properties["title"];
      else if (type === "post")
        mainProperty = label.properties["truncated_raw"];
      else mainProperty = label.properties[0];

      return {
        title: label.title,
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

          if (type === "user") return this._userLabel(label.properties, row);
          if (type === "post") return this._postLabel(label.properties, row);
          if (type === "topic") return this._topicLabel(label.properties, row);
          if (type === "seconds") return this._secondsLabel(value);
          if (type === "link") return this._linkLabel(label.properties, row);
          if (type === "percent") return this._percentLabel(value);
          if (type === "bytes") return this._bytesLabel(value);
          if (type === "number") {
            return this._numberLabel(value, opts);
          }
          if (type === "date") {
            const date = moment(value);
            if (date.isValid()) return this._dateLabel(value, date);
          }
          if (type === "precise_date") {
            const date = moment(value);
            if (date.isValid()) return this._dateLabel(value, date, "LLL");
          }
          if (type === "text") return this._textLabel(value);

          return {
            value,
            type,
            property: mainProperty,
            formatedValue: value ? escapeExpression(value) : "—"
          };
        }
      };
    });
  },

  _userLabel(properties, row) {
    const username = row[properties.username];

    const formatedValue = () => {
      const userId = row[properties.id];

      const user = EmberObject.create({
        username,
        name: formatUsername(username),
        avatar_template: row[properties.avatar]
      });

      const href = Discourse.getURL(`/admin/users/${userId}/${username}`);

      const avatarImg = renderAvatar(user, {
        imageSize: "tiny",
        ignoreTitle: true
      });

      return `<a href='${href}'>${avatarImg}<span class='username'>${user.name}</span></a>`;
    };

    return {
      value: username,
      formatedValue: username ? formatedValue(username) : "—"
    };
  },

  _topicLabel(properties, row) {
    const topicTitle = row[properties.title];

    const formatedValue = () => {
      const topicId = row[properties.id];
      const href = Discourse.getURL(`/t/-/${topicId}`);
      return `<a href='${href}'>${escapeExpression(topicTitle)}</a>`;
    };

    return {
      value: topicTitle,
      formatedValue: topicTitle ? formatedValue() : "—"
    };
  },

  _postLabel(properties, row) {
    const postTitle = row[properties.truncated_raw];
    const postNumber = row[properties.number];
    const topicId = row[properties.topic_id];
    const href = Discourse.getURL(`/t/-/${topicId}/${postNumber}`);

    return {
      property: properties.title,
      value: postTitle,
      formatedValue:
        postTitle && href
          ? `<a href='${href}'>${escapeExpression(postTitle)}</a>`
          : "—"
    };
  },

  _secondsLabel(value) {
    return {
      value: toNumber(value),
      formatedValue: durationTiny(value)
    };
  },

  _percentLabel(value) {
    return {
      value: toNumber(value),
      formatedValue: value ? `${value}%` : "—"
    };
  },

  _numberLabel(value, options = {}) {
    const formatNumbers = Ember.isEmpty(options.formatNumbers)
      ? true
      : options.formatNumbers;

    const formatedValue = () => (formatNumbers ? number(value) : value);

    return {
      value: toNumber(value),
      formatedValue: value ? formatedValue() : "—"
    };
  },

  _bytesLabel(value) {
    return {
      value: toNumber(value),
      formatedValue: I18n.toHumanSize(value)
    };
  },

  _dateLabel(value, date, format = "LL") {
    return {
      value,
      formatedValue: value ? date.format(format) : "—"
    };
  },

  _textLabel(value) {
    const escaped = escapeExpression(value);

    return {
      value,
      formatedValue: value ? escaped : "—"
    };
  },

  _linkLabel(properties, row) {
    const property = properties[0];
    const value = Discourse.getURL(row[property]);
    const formatedValue = (href, anchor) => {
      return `<a href="${escapeExpression(href)}">${escapeExpression(
        anchor
      )}</a>`;
    };

    return {
      value,
      formatedValue: value ? formatedValue(value, row[properties[1]]) : "—"
    };
  },

  _computeChange(valAtT1, valAtT2) {
    return ((valAtT2 - valAtT1) / valAtT1) * 100;
  },

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
  },

  _iconForTrend(trend, higherIsBetter) {
    switch (trend) {
      case "trending-up":
        return higherIsBetter ? "angle-up" : "angle-down";
      case "trending-down":
        return higherIsBetter ? "angle-down" : "angle-up";
      case "high-trending-up":
        return higherIsBetter ? "angle-double-up" : "angle-double-down";
      case "high-trending-down":
        return higherIsBetter ? "angle-double-down" : "angle-double-up";
      default:
        return "minus";
    }
  }
});

Report.reopenClass({
  fillMissingDates(report, options = {}) {
    const dataField = options.dataField || "data";
    const filledField = options.filledField || "data";
    const startDate = options.startDate || "start_date";
    const endDate = options.endDate || "end_date";

    if (_.isArray(report[dataField])) {
      const startDateFormatted = moment
        .utc(report[startDate])
        .locale("en")
        .format("YYYY-MM-DD");
      const endDateFormatted = moment
        .utc(report[endDate])
        .locale("en")
        .format("YYYY-MM-DD");

      if (report.modes[0] === "stacked_chart") {
        report[filledField] = report[dataField].map(rep => {
          return {
            req: rep.req,
            label: rep.label,
            color: rep.color,
            data: fillMissingDates(
              JSON.parse(JSON.stringify(rep.data)),
              startDateFormatted,
              endDateFormatted
            )
          };
        });
      } else {
        report[filledField] = fillMissingDates(
          JSON.parse(JSON.stringify(report[dataField])),
          startDateFormatted,
          endDateFormatted
        );
      }
    }
  },

  find(type, startDate, endDate, categoryId, groupId) {
    return ajax("/admin/reports/" + type, {
      data: {
        start_date: startDate,
        end_date: endDate,
        category_id: categoryId,
        group_id: groupId
      }
    }).then(json => {
      // don’t fill for large multi column tables
      // which are not date based
      const modes = json.report.modes;
      if (modes.length !== 1 && modes[0] !== "table") {
        Report.fillMissingDates(json.report);
      }

      const model = Report.create({ type: type });
      model.setProperties(json.report);

      if (json.report.related_report) {
        // TODO: fillMissingDates if xaxis is date
        const related = Report.create({
          type: json.report.related_report.type
        });
        related.setProperties(json.report.related_report);
        model.set("relatedReport", related);
      }

      return model;
    });
  }
});

export default Report;
