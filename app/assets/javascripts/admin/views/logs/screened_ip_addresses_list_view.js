Discourse.ScreenedIpAddressesListView = Ember.ListView.extend({
  height: 700,
  rowHeight: 32,
  itemViewClass: Ember.ListItemView.extend({templateName: "admin/templates/logs/screened_ip_addresses_list_item"})
});
