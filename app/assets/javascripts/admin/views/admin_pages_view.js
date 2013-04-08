/*global Mousetrap:true */

/**
  A view to handle site pages

  @class AdminPagesView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminPagesView = Discourse.View.extend({
  templateName: 'admin/templates/pages',
  classNames: ['pages'],

  init: function() {
    this._super();
    this.set('selected', 'page');
  },

  pageActive: (function() {
    return this.get('selected') === 'page';
  }).property('selected'),

  selectPage: function() {
    this.set('selected', 'page');
  },
  
  routePlaceholder: (function() {
    return Em.String.i18n("admin.pages.route_placeholder");
  }).property(),

  didInsertElement: function() {
    var _this = this;
    return Mousetrap.bindGlobal(['meta+s', 'ctrl+s'], function() {
      _this.get('controller').save();
      return false;
    });
  },

  willDestroyElement: function() {
    return Mousetrap.unbindGlobal('meta+s', 'ctrl+s');
  }

});
