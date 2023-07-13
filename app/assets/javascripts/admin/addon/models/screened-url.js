import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

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
    return I18n.t("admin.logs.screened_actions." + action);
  }
}
