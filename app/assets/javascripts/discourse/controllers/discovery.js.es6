import ObjectController from 'discourse/controllers/object';
import TopPeriod from 'discourse/models/top-period';

export default ObjectController.extend({
  needs: ['navigation/category', 'discovery/topics', 'application'],
  loading: false,

  category: Em.computed.alias('controllers.navigation/category.category'),
  noSubcategories: Em.computed.alias('controllers.navigation/category.noSubcategories'),

  loadedAllItems: Em.computed.not("controllers.discovery/topics.canLoadMore"),

  _showFooter: function() {
    this.set("controllers.application.showFooter", this.get("loadedAllItems"));
  }.observes("loadedAllItems"),

  showMoreUrl: function(period) {
    var url = '', category = this.get('category');
    if (category) {
      url = '/c/' + Discourse.Category.slugFor(category) + (this.get('noSubcategories') ? '/none' : '') + '/l';
    }
    url += '/top/' + period;
    return url;
  },

  periods: function() {
    var self = this,
        periods = [];
    Discourse.Site.currentProp('periods').forEach(function(p) {
      periods.pushObject(TopPeriod.create({ id: p,
                                            showMoreUrl: self.showMoreUrl(p),
                                            periods: periods }));
    });
    return periods;
  }.property('category', 'noSubcategories'),

});
