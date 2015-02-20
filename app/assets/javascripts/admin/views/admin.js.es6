export default Discourse.View.extend({
  _disableCustomStylesheets: function() {
    $("link.custom-css").attr("rel", "");
  }.on("willInsertElement"),

  _enableCustomStylesheets: function() {
    $("link.custom-css").attr("rel", "stylesheet");
  }.on("willDestroyElement")
});
