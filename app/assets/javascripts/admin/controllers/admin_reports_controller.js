Discourse.AdminReportsController = Ember.ObjectController.extend({
  viewMode: 'table',

  viewingTable: Em.computed.equal('viewMode', 'table'),
  viewingBarChart: Em.computed.equal('viewMode', 'barChart'),

  actions: {
    // Changes the current view mode to 'table'
    viewAsTable: function() {
      this.set('viewMode', 'table');
    },

    // Changes the current view mode to 'barChart'
    viewAsBarChart: function() {
      this.set('viewMode', 'barChart');
    }
  }

});