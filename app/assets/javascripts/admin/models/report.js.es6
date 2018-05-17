import { ajax } from 'discourse/lib/ajax';
import round from "discourse/lib/round";
import { fillMissingDates } from 'discourse/lib/utilities';
import computed from 'ember-addons/ember-computed-decorators';

const Report = Discourse.Model.extend({
  average: false,
  percent: false,

  @computed("type", "start_date", "end_date")
  reportUrl(type, start_date, end_date) {
    start_date = moment(start_date).locale('en').format("YYYY-MM-DD");
    end_date = moment(end_date).locale('en').format("YYYY-MM-DD");
    return Discourse.getURL(`/admin/reports/${type}?start_date=${start_date}&end_date=${end_date}`);
  },

  valueAt(numDaysAgo) {
    if (this.data) {
      const wantedDate = moment().subtract(numDaysAgo, "days").locale('en').format("YYYY-MM-DD");
      const item = this.data.find(d => d.x === wantedDate);
      if (item) {
        return item.y;
      }
    }
    return 0;
  },

  valueFor(startDaysAgo, endDaysAgo) {
    if (this.data) {
      const earliestDate = moment().subtract(endDaysAgo, "days").startOf("day");
      const latestDate = moment().subtract(startDaysAgo, "days").startOf("day");
      var d, sum = 0, count = 0;
      _.each(this.data, datum => {
        d = moment(datum.x);
        if (d >= earliestDate && d <= latestDate) {
          sum += datum.y;
          count++;
        }
      });
      if (this.get("method") === "average" && count > 0) { sum /= count; }
      return round(sum, -2);
    }
  },

  todayCount:          function() { return this.valueAt(0); }.property("data", "average"),
  yesterdayCount:      function() { return this.valueAt(1); }.property("data", "average"),
  sevenDaysAgoCount:   function() { return this.valueAt(7); }.property("data", "average"),
  thirtyDaysAgoCount:  function() { return this.valueAt(30); }.property("data", "average"),
  lastSevenDaysCount:  function() {
    return this.averageCount(7, this.valueFor(1, 7));
  }.property("data", "average"),
  lastThirtyDaysCount: function() {
    return this.averageCount(30, this.valueFor(1, 30));
  }.property("data", "average"),

  averageCount(count, value) {
    return this.get("average") ? value / count : value;
  },

  @computed('yesterdayCount')
  yesterdayTrend(yesterdayCount) {
    const yesterdayVal = yesterdayCount;
    const twoDaysAgoVal = this.valueAt(2);
    const change = ((yesterdayVal - twoDaysAgoVal) / yesterdayVal) * 100;

    if (change > 50) {
      return "high-trending-up";
    } else if (change > 0) {
      return "trending-up";
    } else if (change === 0) {
      return "no-change";
    } else if (change < -50) {
      return "high-trending-down";
    } else if (change < 0) {
      return "trending-down";
    }
  },

  @computed('lastSevenDaysCount')
  sevenDayTrend(lastSevenDaysCount) {
    const currentPeriod = lastSevenDaysCount;
    const prevPeriod = this.valueFor(8, 14);
    const change = ((currentPeriod - prevPeriod) / prevPeriod) * 100;

    if (change > 50) {
      return "high-trending-up";
    } else if (change > 0) {
      return "trending-up";
    } else if (change === 0) {
      return "no-change";
    } else if (change < -50) {
      return "high-trending-down";
    } else if (change < 0) {
      return "trending-down";
    }
  },

  @computed('data')
  currentTotal(data){
    return _.reduce(data, (cur, pair) => cur + pair.y, 0);
  },

  @computed('data', 'currentTotal')
  currentAverage(data, total) {
    return Ember.makeArray(data).length === 0 ? 0 : parseFloat((total / parseFloat(data.length)).toFixed(1));
  },

  @computed("trend")
  trendIcon(trend) {
    switch (trend) {
      case "trending-up":
        return "angle-up";
      case "trending-down":
        return "angle-down";
      case "high-trending-up":
        return "angle-double-up";
      case "high-trending-down":
        return "angle-double-down";
      default:
        return null;
    }
  },

  @computed('prev_period', 'currentTotal', 'currentAverage')
  trend(prev, currentTotal, currentAverage) {
    const total = this.get('average') ? currentAverage : currentTotal;
    const change = ((total - prev) / total) * 100;

    if (change > 50) {
      return "high-trending-up";
    } else if (change > 0) {
      return "trending-up";
    } else if (change === 0) {
      return "no-change";
    } else if (change < -50) {
      return "high-trending-down";
    } else if (change < 0) {
      return "trending-down";
    }
  },

  @computed('prev30Days', 'lastThirtyDaysCount')
  thirtyDayTrend(prev30Days, lastThirtyDaysCount) {
    const currentPeriod = lastThirtyDaysCount;
    const change = ((currentPeriod - prev30Days) / currentPeriod) * 100;

    if (change > 50) {
      return "high-trending-up";
    } else if (change > 0) {
      return "trending-up";
    } else if (change === 0) {
      return "no-change";
    } else if (change < -50) {
      return "high-trending-down";
    } else if (change < 0) {
      return "trending-down";
    }
  },

  @computed('type')
  icon(type) {
    if (type.indexOf("message") > -1) {
      return "envelope";
    }
    switch (type) {
      case "flags": return "flag";
      case "likes": return "heart";
      case "bookmarks": return "bookmark";
      default: return null;
    }
  },

  @computed('type')
  method(type) {
    if (type === "time_to_first_response") {
      return "average";
    } else {
      return "sum";
    }
  },

  percentChangeString(val1, val2) {
    const val = ((val1 - val2) / val2) * 100;
    if (isNaN(val) || !isFinite(val)) {
      return null;
    } else if (val > 0) {
      return "+" + val.toFixed(0) + "%";
    } else {
      return val.toFixed(0) + "%";
    }
  },

  @computed('prev_period', 'currentTotal', 'currentAverage')
  trendTitle(prev, currentTotal, currentAverage) {
    let current = this.get('average') ? currentAverage : currentTotal;
    let percent = this.percentChangeString(current, prev);

    if (this.get('average')) {
      prev = prev ? prev.toFixed(1) : "0";
      if (this.get('percent')) {
        current += '%';
        prev += '%';
      }
    }

    return I18n.t('admin.dashboard.reports.trend_title', {percent: percent, prev: prev, current: current});
  },

  changeTitle(val1, val2, prevPeriodString) {
    const percentChange = this.percentChangeString(val1, val2);
    var title = "";
    if (percentChange) { title += percentChange + " change. "; }
    title += "Was " + val2 + " " + prevPeriodString + ".";
    return title;
  },

  @computed('yesterdayCount')
  yesterdayCountTitle(yesterdayCount) {
    return this.changeTitle(yesterdayCount, this.valueAt(2), "two days ago");
  },

  @computed('lastSevenDaysCount')
  sevenDayCountTitle(lastSevenDaysCount) {
    return this.changeTitle(lastSevenDaysCount, this.valueFor(8, 14), "two weeks ago");
  },

  @computed('prev30Days', 'lastThirtyDaysCount')
  thirtyDayCountTitle(prev30Days, lastThirtyDaysCount) {
    return this.changeTitle(lastThirtyDaysCount, prev30Days, "in the previous 30 day period");
  },

  @computed('data')
  sortedData(data) {
    return this.get('xAxisIsDate') ? data.toArray().reverse() : data.toArray();
  },

  @computed('data')
  xAxisIsDate() {
    if (!this.data[0]) return false;
    return this.data && this.data[0].x.match(/\d{4}-\d{1,2}-\d{1,2}/);
  }

});

Report.reopenClass({

  fillMissingDates(report) {
    if (_.isArray(report.data)) {

      const startDateFormatted = moment.utc(report.start_date).locale('en').format('YYYY-MM-DD');
      const endDateFormatted = moment.utc(report.end_date).locale('en').format('YYYY-MM-DD');
      report.data = fillMissingDates(report.data, startDateFormatted, endDateFormatted);
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
        const related = Report.create({ type: json.report.related_report.type });
        related.setProperties(json.report.related_report);
        model.set('relatedReport', related);
      }

      return model;
    });
  }
});

export default Report;
