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
  filterContent: function() {

    // If we have no content, don't bother filtering anything
    if (!this.present('allSiteSettings')) return;

    var filter;
    if (this.get('filter')) {
      filter = this.get('filter').toLowerCase();
    }

    if ((filter === undefined || filter.length < 1) && !this.get('onlyOverridden')) {
      this.set('model', this.get('allSiteSettings'));
      return;
    }

    var self = this,
        matches,
        matchesGroupedByCategory = Em.A();

    _.each(this.get('allSiteSettings'), function(settingsCategory) {
      matches = settingsCategory.siteSettings.filter(function(item) {
        if (self.get('onlyOverridden') && !item.get('overridden')) return false;
        if (filter) {
          if (item.get('setting').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('description').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('value').toLowerCase().indexOf(filter) > -1) return true;
          return false;
        } else {
          return true;
        }
      });
      if (matches.length > 0) {
        matchesGroupedByCategory.pushObject({
          nameKey: settingsCategory.nameKey,
          name: settingsCategory.name,
          siteSettings: matches});
      }
    });

    this.set('model', matchesGroupedByCategory);
  }.observes('filter', 'onlyOverridden'),

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
