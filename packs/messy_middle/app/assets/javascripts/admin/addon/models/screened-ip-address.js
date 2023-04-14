import { equal } from "@ember/object/computed";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export default class ScreenedIpAddress extends EmberObject {
  static findAll(filter) {
    return ajax("/admin/logs/screened_ip_addresses.json", {
      data: { filter },
    }).then((screened_ips) =>
      screened_ips.map((b) => ScreenedIpAddress.create(b))
    );
  }

  @equal("action_name", "block") isBlocked;
  @discourseComputed("action_name")
  actionName(actionName) {
    return I18n.t(`admin.logs.screened_ips.actions.${actionName}`);
  }

  @discourseComputed("ip_address")
  isRange(ipAddress) {
    return ipAddress.indexOf("/") > 0;
  }

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
  }

  destroy() {
    return ajax("/admin/logs/screened_ip_addresses/" + this.id + ".json", {
      type: "DELETE",
    });
  }
}
