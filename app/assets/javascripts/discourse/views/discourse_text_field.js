/**
  This is a custom text field that allows i18n placeholders

  @class TextField
  @extends Ember.TextField
  @namespace Discourse
  @module Discourse
**/
Discourse.TextField = Ember.TextField.extend({
  attributeBindings: ['autocorrect', 'autocapitalize', 'autofocus'],

  placeholder: function() {

    if( this.get('placeholderKey') ) {
      return I18n.t(this.get('placeholderKey'));
    } else {
      return '';
    }
  }.property('placeholderKey')

});

Discourse.View.registerHelper('textField', Discourse.TextField);
