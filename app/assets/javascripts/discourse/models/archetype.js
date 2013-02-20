(function() {

  window.Discourse.Archetype = Discourse.Model.extend({
    hasOptions: (function() {
      if (!this.get('options')) {
        return false;
      }
      return this.get('options').length > 0;
    }).property('options.@each'),
    isDefault: (function() {
      return this.get('id') === Discourse.get('site.default_archetype');
    }).property('id')
  });

}).call(this);
