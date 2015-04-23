export default Ember.Handlebars.makeBoundHelper(function(str) {
  return Ember.isEmpty(str) ? new Handlebars.SafeString('&mdash;') : str;
});
