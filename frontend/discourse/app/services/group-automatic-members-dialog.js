import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { MAX_AUTO_MEMBERSHIP_DOMAINS_LOOKUP } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";

export default class GroupAutomaticMembersDialog extends Service {
  @service dialog;

  async showConfirm(group_id, email_domains) {
    if (isEmpty(email_domains)) {
      return Promise.resolve(true);
    }

    const domainCount = email_domains.split("|").length;

    // On the back-end we compare every single user's e-mail to each e-mail
    // domain by regular expression. At some point this is a but much work
    // just to display this dialog, so go with a generic message instead.
    if (domainCount > MAX_AUTO_MEMBERSHIP_DOMAINS_LOOKUP) {
      return new Promise((resolve) => {
        this.dialog.confirm({
          message: i18n(
            "admin.groups.manage.membership.automatic_membership_user_unknown_count"
          ),
          didConfirm: () => resolve(true),
          didCancel: () => resolve(false),
        });
      });
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

      if (count > 0) {
        return new Promise((resolve) => {
          this.dialog.confirm({
            message: i18n(
              "admin.groups.manage.membership.automatic_membership_user_count",
              {
                count,
              }
            ),
            didConfirm: () => resolve(true),
            didCancel: () => resolve(false),
          });
        });
      }

      return Promise.resolve(true);
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
