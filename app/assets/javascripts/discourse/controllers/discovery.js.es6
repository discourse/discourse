import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  needs: ['navigation/category', 'discovery/topics', 'application'],
  loading: false,

  category: Em.computed.alias('controllers.navigation/category.category'),
  noSubcategories: Em.computed.alias('controllers.navigation/category.noSubcategories'),

  loadedAllItems: Em.computed.not("controllers.discovery/topics.canLoadMore"),

  _showFooter: function() {
    this.set("controllers.application.showFooter", this.get("loadedAllItems"));
  }.observes("loadedAllItems"),

  showMoreUrl(period) {
    let url = '', category = this.get('category');
    if (category) {
      url = '/c/' + Discourse.Category.slugFor(category) + (this.get('noSubcategories') ? '/none' : '') + '/l';
    }
    url += '/top/' + period;
    return url;
  },

  actions: {
    changePeriod(p) {
      Discourse.URL.routeTo(this.showMoreUrl(p));
    }
  }

});
