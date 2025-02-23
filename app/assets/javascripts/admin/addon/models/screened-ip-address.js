import EmberObject from "@ember/object";
import { equal } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

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
    return i18n(`admin.logs.screened_ips.actions.${actionName}`);
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
