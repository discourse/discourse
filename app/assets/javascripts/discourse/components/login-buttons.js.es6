import { findAll }  from 'discourse/models/login-method';

export default Ember.Component.extend({
  elementId: 'login-buttons',
  classNameBindings: ['hidden'],

  hidden: Ember.computed.equal('buttons.length', 0),

  buttons: function() {
    return findAll(this.siteSettings);
  }.property(),

  actions: {
    externalLogin: function(provider) {
      this.sendAction('action', provider);
    }
  }
});
