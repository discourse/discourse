import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

const ScreenedIpAddress = Discourse.Model.extend({
  @computed("action_name")
  actionName(actionName) {
    return I18n.t(`admin.logs.screened_ips.actions.${actionName}`);
  },

  isBlocked: Ember.computed.equal("action_name", "block"),

  @computed("ip_address")
  isRange(ipAddress) {
    return ipAddress.indexOf("/") > 0;
  },

  save() {
    return ajax("/admin/logs/screened_ip_addresses" + (this.id ? '/' + this.id : '') + ".json", {
      type: this.id ? 'PUT' : 'POST',
      data: {ip_address: this.get('ip_address'), action_name: this.get('action_name')}
    });
  },

  destroy() {
    return ajax("/admin/logs/screened_ip_addresses/" + this.get('id') + ".json", {type: 'DELETE'});
  }
});

ScreenedIpAddress.reopenClass({
  findAll(filter) {
    return ajax("/admin/logs/screened_ip_addresses.json", { data: { filter: filter } })
                    .then(screened_ips => screened_ips.map(b => ScreenedIpAddress.create(b)));
  },

  rollUp() {
    return ajax("/admin/logs/screened_ip_addresses/roll_up", { type: "POST" });
  }
});

export default ScreenedIpAddress;
