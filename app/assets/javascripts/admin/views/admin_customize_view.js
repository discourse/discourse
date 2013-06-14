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

  init: function() {
    this._super();
    this.set('selected', 'stylesheet');
  },

  headerActive: (function() {
    return this.get('selected') === 'header';
  }).property('selected'),

  stylesheetActive: (function() {
    return this.get('selected') === 'stylesheet';
  }).property('selected'),

  selectHeader: function() {
    this.set('selected', 'header');
  },

  selectStylesheet: function() {
    this.set('selected', 'stylesheet');
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
