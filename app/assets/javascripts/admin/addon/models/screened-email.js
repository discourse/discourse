import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

class ScreenedEmail extends EmberObject {
  @discourseComputed("action")
  actionName(action) {
    return I18n.t("admin.logs.screened_actions." + action);
  }

  clearBlock() {
    return ajax("/admin/logs/screened_emails/" + this.id, {
      type: "DELETE",
    });
  }
}

ScreenedEmail.reopenClass({
  findAll() {
    return ajax("/admin/logs/screened_emails.json").then(function (
      screened_emails
    ) {
      return screened_emails.map(function (b) {
        return ScreenedEmail.create(b);
      });
    });
  },
});

export default ScreenedEmail;
