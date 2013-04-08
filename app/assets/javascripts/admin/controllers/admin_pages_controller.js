/**
  This controller supports interface for creating pages in Discourse.

  @class AdminPagesController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminPagesController = Ember.Controller.extend({

  /**
    Create a new page

    @method newPage
  **/
  newPage: function() {
    var item = Discourse.Page.create({name: Em.String.i18n("admin.pages.new_page")});
    this.get('content').pushObject(item);
    this.set('content.selectedItem', item);
  },

  /**
    Select a given page

    @method selectPage
    @param {Discourse.Page} style The page we are selecting
  **/
  selectPage: function(page) {
    this.set('content.selectedItem', page);
  },

  /**
    Save the current page

    @method save
  **/
  save: function() {
    this.get('content.selectedItem').save();
  },

  /**
    Destroy the current page

    @method destroy
  **/
  destroy: function() {
    var _this = this;
    return bootbox.confirm(Em.String.i18n("admin.pages.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      var selected;
      if (result) {
        selected = _this.get('content.selectedItem');
        selected.destroy();
        _this.set('content.selectedItem', null);
        return _this.get('content').removeObject(selected);
      }
    });
  }

});
