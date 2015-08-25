import debounce from 'discourse/lib/debounce';

export default Ember.ArrayController.extend({
  filter: null,
  onlyOverridden: false,
  filtered: Ember.computed.notEmpty('filter'),

  filterContentNow: function(category) {
    // If we have no content, don't bother filtering anything
    if (!!Ember.isEmpty(this.get('allSiteSettings'))) return;

    let filter;
    if (this.get('filter')) {
      filter = this.get('filter').toLowerCase();
    }

    if ((filter === undefined || filter.length < 1) && !this.get('onlyOverridden')) {
      this.set('model', this.get('allSiteSettings'));
      this.transitionToRoute("adminSiteSettings");
      return;
    }

    const self = this,
          matchesGroupedByCategory = [{nameKey: 'all_results', name: I18n.t('admin.site_settings.categories.all_results'), siteSettings: []}];

    this.get('allSiteSettings').forEach(function(settingsCategory) {
      const matches = settingsCategory.siteSettings.filter(function(item) {
        if (self.get('onlyOverridden') && !item.get('overridden')) return false;
        if (filter) {
          if (item.get('setting').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('setting').toLowerCase().replace(/_/g, ' ').indexOf(filter) > -1) return true;
          if (item.get('description').toLowerCase().indexOf(filter) > -1) return true;
          if (item.get('value').toLowerCase().indexOf(filter) > -1) return true;
          return false;
        } else {
          return true;
        }
      });
      if (matches.length > 0) {
        matchesGroupedByCategory[0].siteSettings.pushObjects(matches);
        matchesGroupedByCategory.pushObject({
          nameKey: settingsCategory.nameKey,
          name: I18n.t('admin.site_settings.categories.' + settingsCategory.nameKey),
          siteSettings: matches
        });
      }
    });

    this.set('model', matchesGroupedByCategory);
    this.transitionToRoute("adminSiteSettingsCategory", category || "all_results");
  },

  filterContent: debounce(function() {
    if (this.get("_skipBounce")) {
      this.set("_skipBounce", false);
    } else {
      this.filterContentNow();
    }
  }, 250).observes('filter', 'onlyOverridden'),

  actions: {
    clearFilter() {
      this.setProperties({
        filter: '',
        onlyOverridden: false
      });
    },

    toggleMenu() {
      $('.admin-detail').toggleClass('mobile-closed mobile-open');
    }
  }

});
