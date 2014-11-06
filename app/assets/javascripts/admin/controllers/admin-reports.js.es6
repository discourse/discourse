export default Ember.ObjectController.extend({
  viewMode: 'table',
  viewingTable: Em.computed.equal('viewMode', 'table'),
  viewingBarChart: Em.computed.equal('viewMode', 'barChart'),
  startDate: null,
  endDate: null,
  refreshing: false,

  actions: {
    refreshReport: function() {
      var self = this;
      this.set('refreshing', true);
      Discourse.Report.find(this.get('type'), this.get('startDate'), this.get('endDate')).then(function(r) {
        self.set('model', r);
      }).finally(function() {
        self.set('refreshing', false);
      });
    },

    viewAsTable: function() {
      this.set('viewMode', 'table');
    },

    viewAsBarChart: function() {
      this.set('viewMode', 'barChart');
    }
  }
});
