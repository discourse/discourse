/**
  The base controller for discoverying topics

  @class DiscoveryController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryController = Discourse.ObjectController.extend({
  loading: false,
  loadingSpinner: false,
  scheduledSpinner: null,

  showMoreUrl: function(period) {
    var url = '', category = this.get('category');
    if (category) {
      url = '/category/' + Discourse.Category.slugFor(category) + (this.get('noSubcategories') ? '/none' : '') + '/l';
    }
    url += '/top/' + period;
    return url;
  },

  showMoreDailyUrl: function() { return this.showMoreUrl('daily'); }.property('category', 'noSubcategories'),
  showMoreWeeklyUrl: function() { return this.showMoreUrl('weekly'); }.property('category', 'noSubcategories'),
  showMoreMonthlyUrl: function() { return this.showMoreUrl('monthly'); }.property('category', 'noSubcategories'),
  showMoreYearlyUrl: function() { return this.showMoreUrl('yearly'); }.property('category', 'noSubcategories')
});

