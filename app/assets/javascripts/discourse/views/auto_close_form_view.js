/**
 This view renders the form to set or change a topic or category's auto-close setting.

 @class AutoCloseFormView
 @extends Ember.View
 @namespace Discourse
 @module Discourse
 **/
Discourse.AutoCloseFormView = Ember.View.extend({
  templateName: 'auto_close_form',

  label: function() {
    return I18n.t( this.get('labelKey') || 'composer.auto_close_label' );
  }.property('labelKey'),

  autoCloseChanged: function() {
    if( this.get('autoCloseDays') && this.get('autoCloseDays').length > 0 ) {
      this.set('autoCloseDays', this.get('autoCloseDays').replace(/[^\d]/g, '') );
    }
  }.observes('autoCloseDays')
});

Discourse.View.registerHelper('autoCloseForm', Discourse.AutoCloseFormView);
