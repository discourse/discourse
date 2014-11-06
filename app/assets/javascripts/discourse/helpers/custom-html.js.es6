Handlebars.registerHelper('custom-html', function(name, contextString, options) {
  var html = Discourse.HTML.getCustomHTML(name);
  if (html) { return html; }

  var container = (options || contextString).data.keywords.controller.container;

  if (container.lookup('template:' + name)) {
    return Ember.Handlebars.helpers.partial.apply(this, arguments);
  }
});
