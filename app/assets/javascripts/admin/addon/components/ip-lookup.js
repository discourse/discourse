import { classNames } from "@ember-decorators/component";
import { inject as service } from "@ember/service";
import AdminUser from "admin/models/admin-user";
import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import copyText from "discourse/lib/copy-text";
import discourseComputed from "discourse-common/utils/decorators";
import discourseLater from "discourse-common/lib/later";
import { popupAjaxError } from "discourse/lib/ajax-error";

@classNames("ip-lookup")
export default class IpLookup extends Component {
  @service dialog;

  @discourseComputed("other_accounts.length", "totalOthersWithSameIP")
  otherAccountsToDelete(otherAccountsLength, totalOthersWithSameIP) {
    // can only delete up to 50 accounts at a time
    const total = Math.min(50, totalOthersWithSameIP || 0);
    const visible = Math.min(50, otherAccountsLength || 0);
    return Math.max(visible, total);
  }

  @action
  hide(event) {
    event?.preventDefault();
    this.set("show", false);
  }

  @action
  lookup() {
    this.set("show", true);

    if (!this.location) {
      ajax("/admin/users/ip-info", {
        data: { ip: this.ip },
      }).then((location) => this.set("location", EmberObject.create(location)));
    }

    if (!this.other_accounts) {
      this.set("otherAccountsLoading", true);

      const data = {
        ip: this.ip,
        exclude: this.userId,
        order: "trust_level DESC",
      };

      ajax("/admin/users/total-others-with-same-ip", {
        data,
      }).then((result) => this.set("totalOthersWithSameIP", result.total));

      AdminUser.findAll("active", data).then((users) => {
        this.setProperties({
          other_accounts: users,
          otherAccountsLoading: false,
        });
      });
    }
  }

  @action
  copy() {
    let text = `IP: ${this.ip}\n`;
    const location = this.location;
    if (location) {
      if (location.hostname) {
        text += `${I18n.t("ip_lookup.hostname")}: ${location.hostname}\n`;
      }

      text += I18n.t("ip_lookup.location");
      if (location.location) {
        text += `: ${location.location}\n`;
      } else {
        text += `: ${I18n.t("ip_lookup.location_not_found")}\n`;
      }

      if (location.organization) {
        text += I18n.t("ip_lookup.organisation");
        text += `: ${location.organization}\n`;
      }
    }

    const $copyRange = $('<p id="copy-range"></p>');
    $copyRange.html(text.trim().replace(/\n/g, "<br>"));
    $(document.body).append($copyRange);
    if (copyText(text, $copyRange[0])) {
      this.set("copied", true);
      discourseLater(() => this.set("copied", false), 2000);
    }
    $copyRange.remove();
  }

  @action
  deleteOtherAccounts() {
    this.dialog.yesNoConfirm({
      message: I18n.t("ip_lookup.confirm_delete_other_accounts"),
      didConfirm: () => {
        this.setProperties({
          other_accounts: null,
          otherAccountsLoading: true,
          totalOthersWithSameIP: null,
        });

        ajax("/admin/users/delete-others-with-same-ip.json", {
          type: "DELETE",
          data: {
            ip: this.ip,
            exclude: this.userId,
            order: "trust_level DESC",
          },
        })
          .catch(popupAjaxError)
          .finally(this.send("lookup"));
      },
    });
  }
}
