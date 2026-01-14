import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class EmailSettings extends EmberObject {
  static find() {
    return ajax("/admin/email/server-settings.json").then(function (settings) {
      return EmailSettings.create(settings);
    });
  }
}
