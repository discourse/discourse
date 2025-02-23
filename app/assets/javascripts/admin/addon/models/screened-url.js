import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ScreenedUrl extends EmberObject {
  static findAll() {
    return ajax("/admin/logs/screened_urls.json").then(function (
      screened_urls
    ) {
      return screened_urls.map(function (b) {
        return ScreenedUrl.create(b);
      });
    });
  }

  @discourseComputed("action")
  actionName(action) {
    return i18n("admin.logs.screened_actions." + action);
  }
}
