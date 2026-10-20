import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import ScreenedIpAddress from "discourse/admin/models/screened-ip-address";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

/**
  A form to create an IP address that will be blocked or allowed.
  Example usage:

    <ScreenedIpAddressForm @action={{this.recordAdded}} />

  where action is a callback on the controller or route that will get called after
  the new record is successfully saved. It is called with the new ScreenedIpAddress record
  as an argument.
**/

export default class ScreenedIpAddressForm extends Component {
  @service dialog;
  @service siteSettings;

  @tracked actionName = "block";
  @tracked formSubmitted = false;
  @tracked ipAddress;

  registerInput = modifierFn((element) => {
    this.#input = element;
  });

  #input;

  get actionNames() {
    if (this.siteSettings.use_admin_ip_allowlist) {
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
      this.#input.focus();
    });
  }

  @action
  submitForm() {
    if (!this.formSubmitted) {
      this.formSubmitted = true;
      const screenedIpAddress = ScreenedIpAddress.create({
        ip_address: this.ipAddress,
        action_name: this.actionName,
      });
      screenedIpAddress
        .save()
        .then((result) => {
          this.ipAddress = "";
          this.formSubmitted = false;
          this.args.action(
            ScreenedIpAddress.create(result.screened_ip_address)
          );
          this.focusInput();
        })
        .catch((e) => {
          this.formSubmitted = false;
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
    <form class="screened-ip-address-form inline-form" ...attributes>
      <label>{{i18n "admin.logs.screened_ips.form.label"}}</label>
      <DTextField
        class="ip-address-input"
        @autocapitalize="off"
        @autocorrect="off"
        @disabled={{this.formSubmitted}}
        @placeholderKey="admin.logs.screened_ips.form.ip_address"
        @value={{this.ipAddress}}
        {{this.registerInput}}
      />

      <ComboBox
        @content={{this.actionNames}}
        @onChange={{fn (mut this.actionName)}}
        @value={{this.actionName}}
      />

      <DButton
        class="btn-default"
        type="submit"
        @action={{this.submitForm}}
        @disabled={{this.formSubmitted}}
        @label="admin.logs.screened_ips.form.add"
      />
    </form>
  </template>
}
