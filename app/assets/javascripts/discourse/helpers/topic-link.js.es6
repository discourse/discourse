Handlebars.registerHelper('topic-link', function(property, options) {
  var topic = Ember.Handlebars.get(this, property, options),
      title = topic.get('fancy_title');

  return new Handlebars.SafeString("<a href='" + topic.get('lastUnreadUrl') + "' class='title'>" + title + "</a>");
});
