import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";

const ScreenedIpAddress = EmberObject.extend({
  @discourseComputed("action_name")
  actionName(actionName) {
    return I18n.t(`admin.logs.screened_ips.actions.${actionName}`);
  },

  isBlocked: equal("action_name", "block"),

  @discourseComputed("ip_address")
  isRange(ipAddress) {
    return ipAddress.indexOf("/") > 0;
  },

  save() {
    return ajax(
      "/admin/logs/screened_ip_addresses" +
        (this.id ? "/" + this.id : "") +
        ".json",
      {
        type: this.id ? "PUT" : "POST",
        data: {
          ip_address: this.ip_address,
          action_name: this.action_name,
        },
      }
    );
  },

  destroy() {
    return ajax("/admin/logs/screened_ip_addresses/" + this.id + ".json", {
      type: "DELETE",
    });
  },
});

ScreenedIpAddress.reopenClass({
  findAll(filter) {
    return ajax("/admin/logs/screened_ip_addresses.json", {
      data: { filter },
    }).then((screened_ips) =>
      screened_ips.map((b) => ScreenedIpAddress.create(b))
    );
  },
});

export default ScreenedIpAddress;
