import I18n from "I18n";
import { action } from "@ember/object";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export function popupAutomaticMembershipAlert(group_id, email_domains) {
  if (!email_domains) {
    return;
  }

  const data = {};
  data.automatic_membership_email_domains = email_domains;

  if (group_id) {
    data.id = group_id;
  }

  ajax(`/admin/groups/automatic_membership_count.json`, {
    type: "PUT",
    data
  }).then(result => {
    const count = result.user_count;

    if (count > 0) {
      bootbox.alert(
        I18n.t(
          "admin.groups.manage.membership.automatic_membership_user_count",
          { count }
        )
      );
    }
  });
}

export default Controller.extend({
  saving: null,

  @action
  save() {
    this.set("saving", true);
    const group = this.model;

    popupAutomaticMembershipAlert(
      group.id,
      group.automatic_membership_email_domains
    );

    group
      .create()
      .then(() => {
        this.transitionToRoute("group.members", group.name);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  }
});
