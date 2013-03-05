Discourse.Report = Discourse.Model.extend({});

Discourse.Report.reopenClass({
  find: function(type) {
    var model = Discourse.Report.create();
    $.ajax("/admin/reports/" + type, {
      type: 'GET',
      success: function(json) {
        model.mergeAttributes(json.report);
        model.set('loaded', true);
      }
    });
    return(model);
  }
});