import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

class ScreenedUrl extends EmberObject {
  @discourseComputed("action")
  actionName(action) {
    return I18n.t("admin.logs.screened_actions." + action);
  }
}

ScreenedUrl.reopenClass({
  findAll() {
    return ajax("/admin/logs/screened_urls.json").then(function (
      screened_urls
    ) {
      return screened_urls.map(function (b) {
        return ScreenedUrl.create(b);
      });
    });
  },
});

export default ScreenedUrl;
