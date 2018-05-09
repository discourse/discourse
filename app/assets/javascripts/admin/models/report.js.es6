import { ajax } from 'discourse/lib/ajax';
import round from "discourse/lib/round";
import { fmt } from 'discourse/lib/computed';
import { fillMissingDates } from 'discourse/lib/utilities';
import computed from 'ember-addons/ember-computed-decorators';

const Report = Discourse.Model.extend({
  reportUrl: fmt("type", "/admin/reports/%@"),

  valueAt(numDaysAgo) {
    if (this.data) {
      const wantedDate = moment().subtract(numDaysAgo, "days").format("YYYY-MM-DD");
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

  todayCount:          function() { return this.valueAt(0); }.property("data"),
  yesterdayCount:      function() { return this.valueAt(1); }.property("data"),
  sevenDaysAgoCount:   function() { return this.valueAt(7); }.property("data"),
  thirtyDaysAgoCount:  function() { return this.valueAt(30); }.property("data"),

  lastSevenDaysCount:  function() { return this.valueFor(1, 7); }.property("data"),
  lastThirtyDaysCount: function() { return this.valueFor(1, 30); }.property("data"),

  @computed('data')
  yesterdayTrend() {
    const yesterdayVal = this.valueAt(1);
    const twoDaysAgoVal = this.valueAt(2);
    if (yesterdayVal > twoDaysAgoVal) {
      return "trending-up";
    } else if (yesterdayVal < twoDaysAgoVal) {
      return "trending-down";
    } else {
      return "no-change";
    }
  },

  @computed('data')
  sevenDayTrend() {
    const currentPeriod = this.valueFor(1, 7);
    const prevPeriod = this.valueFor(8, 14);
    if (currentPeriod > prevPeriod) {
      return "trending-up";
    } else if (currentPeriod < prevPeriod) {
      return "trending-down";
    } else {
      return "no-change";
    }
  },

  @computed('prev30Days', 'data')
  thirtyDayTrend(prev30Days) {
    if (prev30Days) {
      const currentPeriod = this.valueFor(1, 30);
      if (currentPeriod > this.get("prev30Days")) {
        return "trending-up";
      } else if (currentPeriod < prev30Days) {
        return "trending-down";
      }
    }
    return "no-change";
  },

  @computed('type')
  icon(type) {
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

  changeTitle(val1, val2, prevPeriodString) {
    const percentChange = this.percentChangeString(val1, val2);
    var title = "";
    if (percentChange) { title += percentChange + " change. "; }
    title += "Was " + val2 + " " + prevPeriodString + ".";
    return title;
  },

  @computed('data')
  yesterdayCountTitle() {
    return this.changeTitle(this.valueAt(1), this.valueAt(2), "two days ago");
  },

  @computed('data')
  sevenDayCountTitle() {
    return this.changeTitle(this.valueFor(1, 7), this.valueFor(8, 14), "two weeks ago");
  },

  @computed('prev30Days', 'data')
  thirtyDayCountTitle(prev30Days) {
    return this.changeTitle(this.valueFor(1, 30), prev30Days, "in the previous 30 day period");
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
      if (json.report.data.length > 0) {
        const startDateFormatted = moment(json.report.start_date).format('YYYY-MM-DD');
        const endDateFormatted = moment(json.report.end_date).format('YYYY-MM-DD');
        json.report.data = fillMissingDates(json.report.data, startDateFormatted, endDateFormatted);
      }

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
