import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class ScreenedIpAddress extends EmberObject {
  static findAll(filter) {
    return ajax("/admin/logs/screened_ip_addresses.json", {
      data: { filter },
    }).then((screened_ips) =>
      screened_ips.map((b) => ScreenedIpAddress.create(b))
    );
  }

  @tracked action_name;

  @dependentKeyCompat
  get isBlocked() {
    return this.action_name === "block";
  }

  @computed("action_name")
  get actionName() {
    return i18n(`admin.logs.screened_ips.actions.${this.action_name}`);
  }

  @computed("ip_address")
  get isRange() {
    return this.ip_address.indexOf("/") > 0;
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
