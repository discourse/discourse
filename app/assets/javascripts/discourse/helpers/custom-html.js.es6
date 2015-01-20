import { getCustomHTML } from 'discourse/lib/html';

Handlebars.registerHelper('custom-html', function(name, contextString, options) {
  var html = getCustomHTML(name);
  if (html) { return html; }

  var container = (options || contextString).data.view.container;
  if (container.lookup('template:' + name)) {
    return Ember.Handlebars.helpers.partial.apply(this, arguments);
  }
});
