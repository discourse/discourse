(function() {

  Discourse.TextField = Ember.TextField.extend({
    attributeBindings: ['autocorrect', 'autocapitalize'],
    placeholder: (function() {
      return Em.String.i18n(this.get('placeholderKey'));
    }).property('placeholderKey')
  });

}).call(this);
