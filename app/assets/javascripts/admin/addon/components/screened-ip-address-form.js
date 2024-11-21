import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ScreenedIpAddress from "admin/models/screened-ip-address";

/**
  A form to create an IP address that will be blocked or allowed.
  Example usage:

    {{screened-ip-address-form action=(action "recordAdded")}}

  where action is a callback on the controller or route that will get called after
  the new record is successfully saved. It is called with the new ScreenedIpAddress record
  as an argument.
**/

@tagName("form")
@classNames("screened-ip-address-form", "inline-form")
export default class ScreenedIpAddressForm extends Component {
  @service dialog;

  formSubmitted = false;
  actionName = "block";

  @discourseComputed("siteSettings.use_admin_ip_allowlist")
  actionNames(adminAllowlistEnabled) {
    if (adminAllowlistEnabled) {
      return [
        { id: "block", name: i18n("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: i18n("admin.logs.screened_ips.actions.do_nothing"),
        },
        {
          id: "allow_admin",
          name: i18n("admin.logs.screened_ips.actions.allow_admin"),
        },
      ];
    } else {
      return [
        { id: "block", name: i18n("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: i18n("admin.logs.screened_ips.actions.do_nothing"),
        },
      ];
    }
  }

  focusInput() {
    schedule("afterRender", () => {
      this.element.querySelector("input").focus();
    });
  }

  @action
  submitForm() {
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
            ? i18n("generic_error_with_reason", {
                error: e.jqXHR.responseJSON.errors.join(". "),
              })
            : i18n("generic_error");
          this.dialog.alert({
            message,
            didConfirm: () => this.focusInput(),
            didCancel: () => this.focusInput(),
          });
        });
    }
  }
}
