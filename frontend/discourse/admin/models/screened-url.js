import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class ScreenedUrl extends EmberObject {
  static findAll() {
    return ajax("/admin/logs/screened_urls.json").then(
      function (screened_urls) {
        return screened_urls.map(function (b) {
          return ScreenedUrl.create(b);
        });
      }
    );
  }

  @computed("action")
  get actionName() {
    return i18n("admin.logs.screened_actions." + this.action);
  }
}
