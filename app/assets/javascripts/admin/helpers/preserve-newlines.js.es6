Em.Handlebars.helper('preserve-newlines', str => {
  return new Handlebars.SafeString(Discourse.Utilities.escapeExpression(str).replace(/\n/g, "<br>"));
});
