Discourse.AdminReportsController = Ember.ObjectController.extend({
  viewMode: 'table',

  // true if we're viewing the table mode
  viewingTable: function() {
    return this.get('viewMode') === 'table';
  }.property('viewMode'),

  // true if we're viewing the bar chart mode
  viewingBarChart: function() {
    return this.get('viewMode') === 'barChart';
  }.property('viewMode'),

  // Changes the current view mode to 'table'
  viewAsTable: function() {
    this.set('viewMode', 'table');
  },

  // Changes the current view mode to 'barChart'
  viewAsBarChart: function() {
    this.set('viewMode', 'barChart');
  }

});