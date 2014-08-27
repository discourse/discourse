export default {
  name: 'verbose-localization',
  initialize: function() {

    if(Discourse.SiteSettings.verbose_localization){
      var counter = 0;
      var keys = {};
      var t = I18n.t;


      I18n.t = I18n.translate = function(scope, value){
        var current = keys[scope];
        if(!current) {
          current = keys[scope] = ++counter;
          var message = "Translation #" + current + ": " + scope;
          if (!_.isEmpty(value)) {
            message += ", parameters: " + JSON.stringify(value);
          }
          window.console.log(message);
        }
        return t.apply(I18n, [scope, value]) + " (t" + current + ")";
      };
    }
  }
};
