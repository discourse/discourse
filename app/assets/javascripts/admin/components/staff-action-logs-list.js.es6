import ListView from 'ember-addons/list-view';
import ListItemView from 'ember-addons/list-item-view';

export default ListView.extend({
  height: 700,
  rowHeight: 75,
  itemViewClass: ListItemView.extend({templateName: "admin/templates/logs/staff-action-logs-list-item"})
});
