/**
  Display logic for dates. It is unbound in Ember but will use jQuery to
  update the dates on a regular interval.
**/
Handlebars.registerHelper('format-date', function(property, options) {
  var leaveAgo, format = 'medium', title = true;
  var hash = property.hash || (options && options.hash);

  if (hash) {
    if (hash.leaveAgo) {
      leaveAgo = hash.leaveAgo === "true";
    }
    if (hash.path) {
      property = hash.path;
    }
    if (hash.format) {
      format = hash.format;
    }
    if (hash.noTitle) {
      title = false;
    }
  }

  var val = Ember.Handlebars.get(this, property, options);
  if (val) {
    var date = new Date(val);
    return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: format, title: title, leaveAgo: leaveAgo}));
  }
});
