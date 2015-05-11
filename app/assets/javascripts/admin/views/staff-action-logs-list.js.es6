import ListView from 'ember-addons/list-view';
import ListItemView from 'ember-addons/list-item-view';

export default ListView.extend({
  height: 700,
  rowHeight: 75,
  itemViewClass: ListItemView.extend({templateName: "admin/templates/logs/staff_action_logs_list_item"})
});
