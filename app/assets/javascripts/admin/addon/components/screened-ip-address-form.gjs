import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ScreenedIpAddress from "admin/models/screened-ip-address";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <label>{{i18n "admin.logs.screened_ips.form.label"}}</label>
    <TextField
      @value={{this.ip_address}}
      @disabled={{this.formSubmitted}}
      @placeholderKey="admin.logs.screened_ips.form.ip_address"
      @autocorrect="off"
      @autocapitalize="off"
      class="ip-address-input"
    />

    <ComboBox
      @content={{this.actionNames}}
      @value={{this.actionName}}
      @onChange={{fn (mut this.actionName)}}
    />

    <DButton
      @action={{this.submitForm}}
      @disabled={{this.formSubmitted}}
      @label="admin.logs.screened_ips.form.add"
      type="submit"
      class="btn-default"
    />
  </template>
}
