(function() {

  /**
    This controller supports interface for creating custom CSS skins in Discourse.

    @class AdminCustomizeController    
    @extends Ember.Controller
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminCustomizeController = Ember.Controller.extend({

    /**
      Create a new customization style

      @method newCustomization
    **/
    newCustomization: function() {
      var item = Discourse.SiteCustomization.create({name: 'New Style'});
      this.get('content').pushObject(item);
      this.set('content.selectedItem', item);
    },

    /**
      Select a given style

      @method selectStyle
      @param {Discourse.SiteCustomization} style The style we are selecting
    **/
    selectStyle: function(style) {
      this.set('content.selectedItem', style);
    },

    /**
      Save the current customization

      @method save
    **/
    save: function() {
      this.get('content.selectedItem').save();
    },

    /**
      Destroy the current customization

      @method destroy
    **/
    destroy: function() {
      var _this = this;
      return bootbox.confirm(Em.String.i18n("admin.customize.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
        var selected;
        if (result) {
          selected = _this.get('content.selectedItem');
          selected["delete"]();
          _this.set('content.selectedItem', null);
          return _this.get('content').removeObject(selected);
        }
      });
    }

  });

}).call(this);
