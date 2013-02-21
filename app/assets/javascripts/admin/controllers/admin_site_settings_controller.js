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

    resetDefault: function(setting) {
      setting.set('value', setting.get('default'));
      setting.save();
    },

    save: function(setting) {
      setting.save();
    },

    cancel: function(setting) {
      setting.resetValue();
    }
    
  });

}).call(this);
