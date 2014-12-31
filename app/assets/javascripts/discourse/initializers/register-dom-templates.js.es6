export default {
  name: "register-discourse-dom-templates",
  before: 'domTemplates',

  // a bit smarter than the default one (domTemplates)
  // figures out raw vs non-raw automatically
  // allows overriding
  initialize: function() {
    $('script[type="text/x-handlebars"]').each(function(){
      var $this = $(this);
      var name = $this.attr("name") || $this.data("template-name");
      Ember.TEMPLATES[name] = name.match(/\.raw$/) ?
        Discourse.EmberCompatHandlebars.compile($this.text()) :
        Ember.Handlebars.compile($this.text());
      $this.remove();
    });
  }
};
