/**
  Inserts a rich code editor

  @method aceEditor
  @for Handlebars
**/
Ember.Handlebars.registerHelper('aceEditor', function(options) {
  var hash = options.hash,
      types = options.hashTypes;

  Discourse.Utilities.normalizeHash(hash, types);

  return Ember.Handlebars.helpers.view.call(this, Discourse.AceEditorView, options);
});