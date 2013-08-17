Discourse.ScreenedEmailsListView = Ember.ListView.extend({
  height: 700,
  rowHeight: 32,
  itemViewClass: Ember.ListItemView.extend({templateName: "admin/templates/logs/screened_emails_list_item"})
});
