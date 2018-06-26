import { ajax } from "discourse/lib/ajax";
import round from "discourse/lib/round";
import { fillMissingDates } from "discourse/lib/utilities";
import computed from "ember-addons/ember-computed-decorators";
import { number } from "discourse/lib/formatter";

const Report = Discourse.Model.extend({
  average: false,
  percent: false,
  higher_is_better: true,

  @computed("type", "start_date", "end_date")
  reportUrl(type, start_date, end_date) {
    start_date = moment(start_date)
      .locale("en")
      .format("YYYY-MM-DD");
    end_date = moment(end_date)
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
      _.each(this.data, datum => {
        d = moment(datum.x);
        if (d >= earliestDate && d <= latestDate) {
          sum += datum.y;
          count++;
        }
      });
      if (this.get("method") === "average" && count > 0) {
        sum /= count;
      }
      return round(sum, -2);
    }
  },

  todayCount: function() {
    return this.valueAt(0);
  }.property("data", "average"),
  yesterdayCount: function() {
    return this.valueAt(1);
  }.property("data", "average"),
  sevenDaysAgoCount: function() {
    return this.valueAt(7);
  }.property("data", "average"),
  thirtyDaysAgoCount: function() {
    return this.valueAt(30);
  }.property("data", "average"),

  lastSevenDaysCount: function() {
    return this.averageCount(7, this.valueFor(1, 7));
  }.property("data", "average"),
  lastThirtyDaysCount: function() {
    return this.averageCount(30, this.valueFor(1, 30));
  }.property("data", "average"),

  averageCount(count, value) {
    return this.get("average") ? value / count : value;
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
    return _.reduce(data, (cur, pair) => cur + pair.y, 0);
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
    const total = this.get("average") ? currentAverage : currentTotal;
    return this._computeTrend(prev, total, higherIsBetter);
  },

  @computed("prev30Days", "lastThirtyDaysCount", "higher_is_better")
  thirtyDaysTrend(prev30Days, lastThirtyDaysCount, higherIsBetter) {
    return this._computeTrend(prev30Days, lastThirtyDaysCount, higherIsBetter);
  },

  @computed("type")
  icon(type) {
    if (type.indexOf("message") > -1) {
      return "envelope";
    }
    switch (type) {
      case "page_view_total_reqs":
        return "file";
      case "visits":
        return "user";
      case "time_to_first_response":
        return "reply";
      case "flags":
        return "flag";
      case "likes":
        return "heart";
      case "bookmarks":
        return "bookmark";
      default:
        return null;
    }
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
    let current = this.get("average") ? currentAverage : currentTotal;
    let percent = this.percentChangeString(prev, current);

    if (this.get("average")) {
      prev = prev ? prev.toFixed(1) : "0";
      if (this.get("percent")) {
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
    return this.get("xAxisIsDate") ? data.toArray().reverse() : data.toArray();
  },

  @computed("data")
  xAxisIsDate() {
    if (!this.data[0]) return false;
    return this.data && this.data[0].x.match(/\d{4}-\d{1,2}-\d{1,2}/);
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
        return null;
    }
  }
});

Report.reopenClass({
  fillMissingDates(report) {
    if (_.isArray(report.data)) {
      const startDateFormatted = moment
        .utc(report.start_date)
        .locale("en")
        .format("YYYY-MM-DD");
      const endDateFormatted = moment
        .utc(report.end_date)
        .locale("en")
        .format("YYYY-MM-DD");
      report.data = fillMissingDates(
        report.data,
        startDateFormatted,
        endDateFormatted
      );
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
      // Add zero values for missing dates
      Report.fillMissingDates(json.report);

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
