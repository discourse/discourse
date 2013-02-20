(function() {

  Ember.Handlebars.registerHelper('i18n', function(property, options) {
    /* Resolve any properties
    */

    var params,
      _this = this;
    params = options.hash;
    Object.keys(params, function(key, value) {
      params[key] = Em.Handlebars.get(_this, value, options);
    });
    return Ember.String.i18n(property, params);
  });

  /* We always prefix with .js to select exactly what we want passed through to the front end.
  */


  Ember.String.i18n = function(scope, options) {
    return I18n.translate("js." + scope, options);
  };

  /* Bind an i18n count
  */


  Ember.Handlebars.registerHelper('countI18n', function(key, options) {
    var view;
    view = Em.View.extend({
      tagName: 'span',
      render: function(buffer) {
        return buffer.push(Ember.String.i18n(key, {
          count: this.get('count')
        }));
      },
      countChanged: (function() {
        return this.rerender();
      }).observes('count')
    });
    return Ember.Handlebars.helpers.view.call(this, view, options);
  });

  if (Ember.EXTEND_PROTOTYPES) {
    String.prototype.i18n = function(options) {
      return Ember.String.i18n(String(this), options);
    };
  }

}).call(this);
