export default Ember.Handlebars.makeBoundHelper(function(str) {
  if (Ember.isEmpty(str)) { return ""; }

  if (str.indexOf('fa-') === 0) {
    return new Handlebars.SafeString("<i class='fa " + str + "'></i>");
  } else {
    return new Handlebars.SafeString("<img src='" + str + "'>");
  }
});
