import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const ScreenedUrl = EmberObject.extend({
  @discourseComputed("action")
  actionName(action) {
    return I18n.t("admin.logs.screened_actions." + action);
  }
});

ScreenedUrl.reopenClass({
  findAll: function() {
    return ajax("/admin/logs/screened_urls.json").then(function(screened_urls) {
      return screened_urls.map(function(b) {
        return ScreenedUrl.create(b);
      });
    });
  }
});

export default ScreenedUrl;
