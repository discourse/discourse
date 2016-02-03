import round from "discourse/lib/round";
import { fmt } from 'discourse/lib/computed';

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

  yesterdayTrend: function() {
    const yesterdayVal = this.valueAt(1);
    const twoDaysAgoVal = this.valueAt(2);
    if (yesterdayVal > twoDaysAgoVal) {
      return "trending-up";
    } else if (yesterdayVal < twoDaysAgoVal) {
      return "trending-down";
    } else {
      return "no-change";
    }
  }.property("data"),

  sevenDayTrend: function() {
    const currentPeriod = this.valueFor(1, 7);
    const prevPeriod = this.valueFor(8, 14);
    if (currentPeriod > prevPeriod) {
      return "trending-up";
    } else if (currentPeriod < prevPeriod) {
      return "trending-down";
    } else {
      return "no-change";
    }
  }.property("data"),

  thirtyDayTrend: function() {
    if (this.get("prev30Days")) {
      const currentPeriod = this.valueFor(1, 30);
      if (currentPeriod > this.get("prev30Days")) {
        return "trending-up";
      } else if (currentPeriod < this.get("prev30Days")) {
        return "trending-down";
      }
    }
    return "no-change";
  }.property("data", "prev30Days"),

  icon: function() {
    switch (this.get("type")) {
      case "flags": return "flag";
      case "likes": return "heart";
      default:      return null;
    }
  }.property("type"),

  method: function() {
    if (this.get("type") === "time_to_first_response") {
      return "average";
    } else {
      return "sum";
    }
  }.property("type"),

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

  yesterdayCountTitle: function() {
    return this.changeTitle(this.valueAt(1), this.valueAt(2), "two days ago");
  }.property("data"),

  sevenDayCountTitle: function() {
    return this.changeTitle(this.valueFor(1, 7), this.valueFor(8, 14), "two weeks ago");
  }.property("data"),

  thirtyDayCountTitle: function() {
    return this.changeTitle(this.valueFor(1, 30), this.get("prev30Days"), "in the previous 30 day period");
  }.property("data"),

  dataReversed: function() {
    return this.get("data").toArray().reverse();
  }.property("data")

});

Report.reopenClass({

  find(type, startDate, endDate, categoryId, groupId) {
    return Discourse.ajax("/admin/reports/" + type, {
      data: {
        start_date: startDate,
        end_date: endDate,
        category_id: categoryId,
        group_id: groupId
      }
    }).then(json => {
      // Add a percent field to each tuple
      let maxY = 0;
      json.report.data.forEach(row => {
        if (row.y > maxY) maxY = row.y;
      });
      if (maxY > 0) {
        json.report.data.forEach(row => row.percentage = Math.round((row.y / maxY) * 100));
      }
      const model = Report.create({ type: type });
      model.setProperties(json.report);
      return model;
    });
  }
});

export default Report;
