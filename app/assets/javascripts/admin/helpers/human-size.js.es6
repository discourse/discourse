Em.Handlebars.helper('human-size', function(size) {
  return new Handlebars.SafeString(I18n.toHumanSize(size));
});
