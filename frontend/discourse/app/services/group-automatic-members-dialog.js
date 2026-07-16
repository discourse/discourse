import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class GroupAutomaticMembersDialog extends Service {
  @service dialog;

  async showConfirm(group_id, email_domains) {
    if (isEmpty(email_domains)) {
      return true;
    }

    const data = { automatic_membership_email_domains: email_domains };

    if (group_id) {
      data.id = group_id;
    }

    try {
      const result = await ajax(
        `/admin/groups/automatic_membership_count.json`,
        {
          type: "PUT",
          data,
        }
      );

      const count = result.user_count;

      if (count === null) {
        return this.dialog.confirm({
          message: i18n(
            "admin.groups.manage.membership.automatic_membership_user_unknown_count"
          ),
        });
      }

      if (count > 0) {
        return this.dialog.confirm({
          message: i18n(
            "admin.groups.manage.membership.automatic_membership_user_count",
            { count }
          ),
        });
      }

      return true;
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
