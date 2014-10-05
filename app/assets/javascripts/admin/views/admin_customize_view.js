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
  selected: 'stylesheet',
  headerActive:           Em.computed.equal('selected', 'header'),
  stylesheetActive:       Em.computed.equal('selected', 'stylesheet'),
  mobileHeaderActive:     Em.computed.equal('selected', 'mobileHeader'),
  mobileStylesheetActive: Em.computed.equal('selected', 'mobileStylesheet'),

  actions: {
    selectHeader:           function() { this.set('selected', 'header'); },
    selectStylesheet:       function() { this.set('selected', 'stylesheet'); },
    selectMobileHeader:     function() { this.set('selected', 'mobileHeader'); },
    selectMobileStylesheet: function() { this.set('selected', 'mobileStylesheet'); }
  },

  didInsertElement: function() {
    var controller = this.get('controller');
    Mousetrap.bindGlobal('mod+s', function() {
      controller.send("save");
      return false;
    });
  },

  willDestroyElement: function() {
    Mousetrap.unbindGlobal('mod+s');
  }

});
