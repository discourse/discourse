import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { removeRegistrationForm } from "../lib/registration-forms.js";

export default class DeleteRegistrationFormButton extends Component {
  @service dialog;
  @service router;

  get accessibleLabel() {
    return i18n("event_registration.library.delete_named_form", {
      title: this.args.formTitle,
    });
  }

  @action
  async deleteForm() {
    const confirmed = await this.dialog.deleteConfirm({
      title: i18n("event_registration.library.delete_title", {
        title: this.args.formTitle,
      }),
      message: i18n("event_registration.library.delete_help"),
      confirmButtonLabel: "delete",
    });
    if (!confirmed) {
      return;
    }
    try {
      await removeRegistrationForm(this.args.formId);
      if (this.args.onDeleted) {
        this.args.onDeleted();
      } else {
        await this.router.refresh(this.router.currentRouteName);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DButton
      ...attributes
      @action={{this.deleteForm}}
      @disabled={{@inUse}}
      @icon={{unless @label "trash-can"}}
      @label={{@label}}
      @title={{if @inUse "event_registration.library.delete_in_use"}}
      @translatedAriaLabel={{this.accessibleLabel}}
      @translatedTitle={{unless @label this.accessibleLabel}}
    />
  </template>
}
