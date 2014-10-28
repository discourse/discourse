/**
  Display logic for dates. It is unbound in Ember but will use jQuery to
  update the dates on a regular interval.
**/
Handlebars.registerHelper('format-date', function(property, options) {
  var leaveAgo;
  if (property.hash) {
    if (property.hash.leaveAgo) {
      leaveAgo = property.hash.leaveAgo === "true";
    }
    if (property.hash.path) {
      property = property.hash.path;
    }
  }

  var val = Ember.Handlebars.get(this, property, options);
  if (val) {
    var date = new Date(val);
    return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: leaveAgo}));
  }
});
