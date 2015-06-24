export default Ember.ObjectController.extend({
  viewMode: 'table',
  viewingTable: Em.computed.equal('viewMode', 'table'),
  viewingBarChart: Em.computed.equal('viewMode', 'barChart'),
  startDate: null,
  endDate: null,
  categoryId: null,
  refreshing: false,

  actions: {
    refreshReport() {
      this.set("refreshing", true);
      Discourse.Report.find(
        this.get("type"),
        this.get("startDate"),
        this.get("endDate"),
        this.get("categoryId")
      ).then(m => this.set("model", m)
      ).finally(() => this.set("refreshing", false));
    },

    viewAsTable() {
      this.set('viewMode', 'table');
    },

    viewAsBarChart() {
      this.set('viewMode', 'barChart');
    }
  }
});
