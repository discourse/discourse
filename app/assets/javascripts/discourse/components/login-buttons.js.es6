import { findAll }  from 'discourse/models/login-method';
import { getOwner } from 'discourse-common/lib/get-owner';

export default Ember.Component.extend({
  elementId: 'login-buttons',
  classNameBindings: ['hidden'],

  hidden: Ember.computed.equal('buttons.length', 0),

  buttons: function() {
    return findAll(this.siteSettings, getOwner(this).lookup('capabilities:main'), this.site.isMobileDevice);
  }.property(),

  actions: {
    externalLogin: function(provider) {
      this.sendAction('action', provider);
    }
  }
});
