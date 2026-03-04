import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class ScreenedEmail extends EmberObject {
  static findAll() {
    return ajax("/admin/logs/screened_emails.json").then(
      function (screened_emails) {
        return screened_emails.map(function (b) {
          return ScreenedEmail.create(b);
        });
      }
    );
  }

  @computed("action")
  get actionName() {
    return i18n("admin.logs.screened_actions." + this.action);
  }

  clearBlock() {
    return ajax("/admin/logs/screened_emails/" + this.id, {
      type: "DELETE",
    });
  }
}
