export default Ember.Controller.extend({
  viewMode: 'table',
  viewingTable: Em.computed.equal('viewMode', 'table'),
  viewingBarChart: Em.computed.equal('viewMode', 'barChart'),
  startDate: null,
  endDate: null,
  categoryId: null,
  refreshing: false,

  categoryOptions: function() {
    var arr = [{name: I18n.t('category.all'), value: 'all'}];
    return arr.concat( Discourse.Site.currentProp('sortedCategories').map(function(i) { return {name: i.get('name'), value: i.get('id') }; }) );
  }.property(),

  actions: {
    refreshReport() {
      var q;
      this.set("refreshing", true);
      if (this.get('categoryId') === "all") {
        q = Discourse.Report.find(this.get("model.type"), this.get("startDate"), this.get("endDate"));
      } else {
        q = Discourse.Report.find(this.get("model.type"), this.get("startDate"), this.get("endDate"), this.get("categoryId"));
      }
      q.then(m => this.set("model", m)).finally(() => this.set("refreshing", false));
    },

    viewAsTable() {
      this.set('viewMode', 'table');
    },

    viewAsBarChart() {
      this.set('viewMode', 'barChart');
    }
  }
});
