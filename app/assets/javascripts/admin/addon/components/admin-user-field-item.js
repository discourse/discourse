import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n, propertyEqual } from "discourse/lib/computed";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import UserField from "admin/models/user-field";

export default Component.extend(bufferedProperty("userField"), {
  adminCustomUserFields: service(),

  tagName: "",
  isEditing: false,

  cantMoveUp: propertyEqual("userField", "firstField"),
  cantMoveDown: propertyEqual("userField", "lastField"),

  userFieldsDescription: i18n("admin.user_fields.description"),

  @discourseComputed("buffered.field_type")
  bufferedFieldType(fieldType) {
    return UserField.fieldTypeById(fieldType);
  },

  didInsertElement() {
    this._super(...arguments);

    this._focusName();
  },

  _focusName() {
    schedule("afterRender", () => {
      document.querySelector(".user-field-name")?.focus();
    });
  },

  @discourseComputed("userField.field_type")
  fieldName(fieldType) {
    return UserField.fieldTypeById(fieldType)?.name;
  },

  @discourseComputed(
    "userField.{editable,show_on_profile,show_on_user_card,searchable}"
  )
  flags(userField) {
    const ret = [];
    if (userField.editable) {
      ret.push(I18n.t("admin.user_fields.editable.enabled"));
    }
    if (userField.show_on_profile) {
      ret.push(I18n.t("admin.user_fields.show_on_profile.enabled"));
    }
    if (userField.show_on_user_card) {
      ret.push(I18n.t("admin.user_fields.show_on_user_card.enabled"));
    }
    if (userField.searchable) {
      ret.push(I18n.t("admin.user_fields.searchable.enabled"));
    }

    return ret.join(", ");
  },

  @action
  save() {
    const attrs = this.buffered.getProperties(
      "name",
      "description",
      "field_type",
      "editable",
      "requirement",
      "show_on_profile",
      "show_on_user_card",
      "searchable",
      "options",
      ...this.adminCustomUserFields.additionalProperties
    );

    return this.userField
      .save(attrs)
      .then(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isEditing", false);
        this.commitBuffer();
      })
      .catch(popupAjaxError);
  },

  @action
  edit() {
    this.set("isEditing", true);
    this._focusName();
  },

  @action
  cancel() {
    if (isEmpty(this.userField?.id)) {
      this.destroyAction(this.userField);
    } else {
      this.rollbackBuffer();
      this.set("isEditing", false);
    }
  },
});
