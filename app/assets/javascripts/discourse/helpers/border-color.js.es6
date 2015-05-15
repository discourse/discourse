export default Ember.Handlebars.makeBoundHelper(function(value) {
  return ("border-color: #" + value).htmlSafe();
});

