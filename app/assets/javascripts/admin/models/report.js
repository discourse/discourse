Discourse.Report = Discourse.Model.extend({
  reportUrl: function() {
    return("/admin/reports/" + this.get('type'));
  }.property('type')
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
