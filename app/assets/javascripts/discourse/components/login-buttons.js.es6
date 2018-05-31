import { findAll }  from 'discourse/models/login-method';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  elementId: 'login-buttons',
  classNameBindings: ['hidden'],

  hidden: Ember.computed.equal('buttons.length', 0),

  @computed
  buttons() {
    return findAll(this.siteSettings, this.capabilities, this.site.isMobileDevice);
  },

  actions: {
    emailLogin() {
      this.sendAction('emailLogin');
    },

    externalLogin(provider) {
      this.sendAction('externalLogin', provider);
    }
  }
});
