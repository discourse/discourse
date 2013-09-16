/*global Mousetrap:true */

/**
  A view to handle site customizations

  @class AdminCustomizeView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeView = Discourse.View.extend({
  templateName: 'admin/templates/customize',
  classNames: ['customize'],
  headerActive: Ember.computed.equal('selected', 'header'),
  stylesheetActive: Ember.computed.equal('selected', 'stylesheet'),
  mobileHeaderActive: Ember.computed.equal('selected', 'mobileHeader'),
  mobileStylesheetActive: Ember.computed.equal('selected', 'mobileStylesheet'),

  init: function() {
    this._super();
    this.set('selected', 'stylesheet');
  },

  selectHeader: function() {
    this.set('selected', 'header');
  },

  selectStylesheet: function() {
    this.set('selected', 'stylesheet');
  },

  selectMobileHeader: function() {
    this.set('selected', 'mobileHeader');
  },

  selectMobileStylesheet: function() {
    this.set('selected', 'mobileStylesheet');
  },

  didInsertElement: function() {
    var controller = this.get('controller');
    return Mousetrap.bindGlobal(['meta+s', 'ctrl+s'], function() {
      controller.save();
      return false;
    });
  },

  willDestroyElement: function() {
    return Mousetrap.unbindGlobal('meta+s', 'ctrl+s');
  }

});
