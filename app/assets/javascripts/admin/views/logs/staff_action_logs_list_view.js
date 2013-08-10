Discourse.StaffActionLogsListView = Ember.ListView.extend({
  height: 700,
  rowHeight: 75,
  itemViewClass: Ember.ListItemView.extend({templateName: "admin/templates/logs/staff_action_logs_list_item"})
});
