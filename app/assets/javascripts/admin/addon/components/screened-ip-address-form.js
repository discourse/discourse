import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import ScreenedIpAddress from "admin/models/screened-ip-address";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";

/**
  A form to create an IP address that will be blocked or allowed.
  Example usage:

    {{screened-ip-address-form action=(action "recordAdded")}}

  where action is a callback on the controller or route that will get called after
  the new record is successfully saved. It is called with the new ScreenedIpAddress record
  as an argument.
**/

export default Component.extend({
  tagName: "form",
  dialog: service(),
  classNames: ["screened-ip-address-form", "inline-form"],
  formSubmitted: false,
  actionName: "block",

  @discourseComputed("siteSettings.use_admin_ip_allowlist")
  actionNames(adminAllowlistEnabled) {
    if (adminAllowlistEnabled) {
      return [
        { id: "block", name: I18n.t("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: I18n.t("admin.logs.screened_ips.actions.do_nothing"),
        },
        {
          id: "allow_admin",
          name: I18n.t("admin.logs.screened_ips.actions.allow_admin"),
        },
      ];
    } else {
      return [
        { id: "block", name: I18n.t("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: I18n.t("admin.logs.screened_ips.actions.do_nothing"),
        },
      ];
    }
  },

  focusInput() {
    schedule("afterRender", () => {
      this.element.querySelector("input").focus();
    });
  },

  actions: {
    submit() {
      if (!this.formSubmitted) {
        this.set("formSubmitted", true);
        const screenedIpAddress = ScreenedIpAddress.create({
          ip_address: this.ip_address,
          action_name: this.actionName,
        });
        screenedIpAddress
          .save()
          .then((result) => {
            this.setProperties({ ip_address: "", formSubmitted: false });
            this.action(ScreenedIpAddress.create(result.screened_ip_address));
            this.focusInput();
          })
          .catch((e) => {
            this.set("formSubmitted", false);
            const message = e.jqXHR.responseJSON?.errors
              ? I18n.t("generic_error_with_reason", {
                  error: e.jqXHR.responseJSON.errors.join(". "),
                })
              : I18n.t("generic_error");
            this.dialog.alert({
              message,
              didConfirm: () => this.focusInput(),
              didCancel: () => this.focusInput(),
            });
          });
      }
    },
  },
});
