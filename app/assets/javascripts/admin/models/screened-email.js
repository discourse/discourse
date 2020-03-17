import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const ScreenedEmail = EmberObject.extend({
  @discourseComputed("action")
  actionName(action) {
    return I18n.t("admin.logs.screened_actions." + action);
  },

  clearBlock: function() {
    return ajax("/admin/logs/screened_emails/" + this.id, {
      method: "DELETE"
    });
  }
});

ScreenedEmail.reopenClass({
  findAll: function() {
    return ajax("/admin/logs/screened_emails.json").then(function(
      screened_emails
    ) {
      return screened_emails.map(function(b) {
        return ScreenedEmail.create(b);
      });
    });
  }
});

export default ScreenedEmail;
