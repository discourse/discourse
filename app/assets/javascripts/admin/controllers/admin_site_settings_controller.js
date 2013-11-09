/**
  This controller supports the interface for SiteSettings.

  @class AdminSiteSettingsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteSettingsController = Ember.ArrayController.extend(Discourse.Presence, {
  filter: null,
  onlyOverridden: false,

  /**
    The list of settings based on the current filters

    @property filteredContent
  **/
  filteredContent: function() {

    // If we have no content, don't bother filtering anything
    if (!this.present('content')) return null;

    var filter;
    if (this.get('filter')) {
      filter = this.get('filter').toLowerCase();
    }

    var adminSettingsController = this;

    var maxResults = Em.isNone(filter) ? this.get('content.length') : 20;
    return _.first(this.get('content').filter(function(item, index, enumerable) {
      if (adminSettingsController.get('onlyOverridden') && !item.get('overridden')) return false;
      if (filter) {
        if (item.get('setting').toLowerCase().indexOf(filter) > -1) return true;
        if (item.get('description').toLowerCase().indexOf(filter) > -1) return true;
        if (item.get('value').toLowerCase().indexOf(filter) > -1) return true;
        return false;
      }

      return true;
    }), maxResults);
  }.property('filter', 'content.@each', 'onlyOverridden'),

  actions: {

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
  }

});
