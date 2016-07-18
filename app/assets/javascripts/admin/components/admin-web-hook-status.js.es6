import computed from 'ember-addons/ember-computed-decorators';
import StringBuffer from 'discourse/mixins/string-buffer';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend(StringBuffer, {
  @computed('deliveryStatuses')
  statusName(deliveryStatuses) {
    return deliveryStatuses.find(s => s.id === this.get('model.last_delivery_status')).name;
  },

  @computed('statusName')
  icon(statusName) {
    switch (statusName) {
      case 'inactive': return 'circle-o';
      case 'failed': return 'times-circle';
      case 'successful': return 'circle';
      default: return '';
    }
  },

  @computed('statusName')
  classes(statusName) {
    switch (statusName) {
      case 'inactive': return 'text-muted';
      case 'failed': return 'text-danger';
      case 'successful': return 'text-successful';
      default: return '';
    }
  },

  renderString(buffer) {
    buffer.push(iconHTML(this.get('icon'), { class: this.get('classes') }));
    buffer.push(I18n.t(`admin.web_hooks.delivery_status.${this.get('statusName')}`));
  }
});
