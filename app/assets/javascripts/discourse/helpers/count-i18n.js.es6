/**
  Set up an i18n binding that will update as a count changes, complete with pluralization.

  @method countI18n
  @for Handlebars
**/
Ember.Handlebars.registerHelper('countI18n', function(key, options) {
  var view = Discourse.View.extend(Discourse.StringBuffer, {
    tagName: 'span',
    rerenderTriggers: ['count', 'suffix'],

    renderString: function(buffer) {
      buffer.push(I18n.t(key + (this.get('suffix') || ''), { count: this.get('count') }));
    }
  });
  return Ember.Handlebars.helpers.view.call(this, view, options);
});
