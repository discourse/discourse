import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { Promise } from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import UserField from "admin/models/user-field";

@tagName("")
export default class AdminUserFieldItem extends Component {
  @service adminCustomUserFields;
  @service dialog;

  @tracked isEditing = false;
  @tracked
  editableDisabled = this.args.userField.requirement === "for_all_users";

  originalRequirement = this.args.userField.requirement;

  get fieldName() {
    return UserField.fieldTypeById(this.fieldType)?.name;
  }

  get cantMoveUp() {
    return this.args.userField.id === this.args.firstField?.id;
  }

  get cantMoveDown() {
    return this.args.userField.id === this.args.lastField?.id;
  }

  get isNewRecord() {
    return isEmpty(this.args.userField?.id);
  }

  get flags() {
    const flags = [
      "editable",
      "show_on_profile",
      "show_on_user_card",
      "searchable",
    ];

    return flags
      .map((flag) => {
        if (this.args.userField[flag]) {
          return I18n.t(`admin.user_fields.${flag}.enabled`);
        }
      })
      .filter(Boolean)
      .join(", ");
  }

  @cached
  get formData() {
    return this.args.userField.getProperties(
      "field_type",
      "name",
      "description",
      "requirement",
      "editable",
      "show_on_profile",
      "show_on_user_card",
      "searchable",
      "options",
      ...this.adminCustomUserFields.additionalProperties
    );
  }

  @action
  setRequirement(value, { set }) {
    set("requirement", value);

    if (value === "for_all_users") {
      this.editableDisabled = true;
      set("editable", true);
    } else {
      this.editableDisabled = false;
    }
  }

  @action
  async save(data) {
    let confirm = true;

    if (
      data.requirement === "for_all_users" &&
      this.originalRequirement !== "for_all_users"
    ) {
      confirm = await this._confirmChanges();
    }

    if (!confirm) {
      return;
    }

    return this.args.userField
      .save(data)
      .then(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.originalRequirement = data.requirement;
        this.isEditing = false;
      })
      .catch(popupAjaxError);
  }

  async _confirmChanges() {
    return new Promise((resolve) => {
      this.dialog.yesNoConfirm({
        message: I18n.t("admin.user_fields.requirement.confirmation"),
        didCancel: () => resolve(false),
        didConfirm: () => resolve(true),
      });
    });
  }

  @action
  edit() {
    this.isEditing = true;
  }

  @action
  cancel() {
    if (this.isNewRecord) {
      this.args.destroyAction(this.args.userField);
    } else {
      this.isEditing = false;
    }
  }

  _focusName() {
    schedule("afterRender", () =>
      document.querySelector(".user-field-name")?.focus()
    );
  }
}
