Discourse.Report = Discourse.Model.extend({
  reportUrl: function() {
    return("/admin/reports/" + this.get('type'));
  }.property('type'),

  valueAt: function(numDaysAgo) {
    if (this.data) {
      var wantedDate = Date.create(numDaysAgo + ' days ago', 'en').format('{yyyy}-{MM}-{dd}');
      var item = this.data.find( function(d, i, arr) { return d.x === wantedDate; } );
      if (item) {
        return item.y;
      }
    }
    return 0;
  },

  sumDays: function(startDaysAgo, endDaysAgo) {
    if (this.data) {
      var earliestDate = Date.create(endDaysAgo + ' days ago', 'en');
      var latestDate = Date.create(startDaysAgo + ' days ago', 'en');
      var d, sum = 0;
      this.data.each(function(datum){
        d = Date.create(datum.x);
        if(d >= earliestDate && d <= latestDate) {
          sum += datum.y;
        }
      });
      return sum;
    }
  },

  yesterdayTrend: function() {
    var yesterdayVal = this.valueAt(1);
    var twoDaysAgoVal = this.valueAt(2);
    if ( yesterdayVal > twoDaysAgoVal ) {
      return 'trending-up';
    } else if ( yesterdayVal < twoDaysAgoVal ) {
      return 'trending-down';
    } else {
      return 'no-change';
    }
  }.property('data'),

  sevenDayTrend: function() {
    var currentPeriod = this.sumDays(1,7);
    var prevPeriod = this.sumDays(8,14);
    if ( currentPeriod > prevPeriod ) {
      return 'trending-up';
    } else if ( currentPeriod < prevPeriod ) {
      return 'trending-down';
    } else {
      return 'no-change';
    }
  }.property('data'),

  thirtyDayTrend: function() {
    if( this.get('prev30Days') ) {
      var currentPeriod = this.sumDays(1,30);
      if( currentPeriod > this.get('prev30Days') ) {
        return 'trending-up';
      } else if ( currentPeriod < this.get('prev30Days') ) {
        return 'trending-down';
      }
    }
    return 'no-change';
  }.property('data', 'prev30Days')
});

Discourse.Report.reopenClass({
  find: function(type) {
    var model = Discourse.Report.create({type: type});
    $.ajax(Discourse.getURL("/admin/reports/") + type, {
      type: 'GET',
      success: function(json) {

        // Add a percent field to each tuple
        var maxY = 0;
        json.report.data.forEach(function (row) {
          if (row.y > maxY) maxY = row.y;
        });
        if (maxY > 0) {
          json.report.data.forEach(function (row) {
            row.percentage = Math.round((row.y / maxY) * 100);
          });
        }

        model.mergeAttributes(json.report);
        model.set('loaded', true);
      }
    });
    return(model);
  }
});
