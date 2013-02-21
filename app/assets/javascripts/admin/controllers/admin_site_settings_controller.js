(function() {

  /**
    This controller supports the interface for SiteSettings.

    @class AdminSiteSettingsController    
    @extends Ember.ArrayController
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminSiteSettingsController = Ember.ArrayController.extend(Discourse.Presence, {
    filter: null,
    onlyOverridden: false,

    /**
      The list of settings based on the current filters

      @property filteredContent
    **/
    filteredContent: (function() {
      var filter,
        _this = this;
      if (!this.present('content')) return null;
      if (this.get('filter')) {
        filter = this.get('filter').toLowerCase();
      }

      return this.get('content').filter(function(item, index, enumerable) {
        if (_this.get('onlyOverridden') && !item.get('overridden')) return false;
        if (filter) {
          if (item.get('setting').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('description').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('value').toLowerCase().indexOf(filter) > -1) return true;
          return false;
        }

        return true;
      });
    }).property('filter', 'content.@each', 'onlyOverridden'),

    /**
      Reset a setting to its default value

      @method resetDefault
      @param {Discourse.SiteSetting} setting The setting we want to revert
    **/
    resetDefault: function(setting) {
      setting.set('value', setting.get('default'));
      setting.save();
    },

    /**
      Save changes to a site setting

      @method save
      @param {Discourse.SiteSetting} setting The setting we've changed
    **/
    save: function(setting) {
      setting.save();
    },

    /**
      Cancel changes to a site setting

      @method cancel
      @param {Discourse.SiteSetting} setting The setting we've changed but want to revert
    **/
    cancel: function(setting) {
      setting.resetValue();
    }
    
  });

}).call(this);
