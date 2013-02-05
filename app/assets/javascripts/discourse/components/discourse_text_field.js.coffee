Discourse.TextField = Ember.TextField.extend

  attributeBindings: ['autocorrect', 'autocapitalize']

  placeholder: (->
    Em.String.i18n(@get('placeholderKey'))
  ).property('placeholderKey')
