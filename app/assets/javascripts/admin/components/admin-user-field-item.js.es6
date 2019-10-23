import Component from "@ember/component";
import UserField from "admin/models/user-field";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { propertyEqual } from "discourse/lib/computed";
import { i18n } from "discourse/lib/computed";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";

export default Component.extend(bufferedProperty("userField"), {
  editing: Ember.computed.empty("userField.id"),
  classNameBindings: [":user-field"],

  cantMoveUp: propertyEqual("userField", "firstField"),
  cantMoveDown: propertyEqual("userField", "lastField"),

  userFieldsDescription: i18n("admin.user_fields.description"),

  @computed("buffered.field_type")
  bufferedFieldType(fieldType) {
    return UserField.fieldTypeById(fieldType);
  },

  @on("didInsertElement")
  @observes("editing")
  _focusOnEdit() {
    if (this.editing) {
      Ember.run.scheduleOnce("afterRender", this, "_focusName");
    }
  },

  _focusName() {
    $(".user-field-name").select();
  },

  @computed("userField.field_type")
  fieldName(fieldType) {
    return UserField.fieldTypeById(fieldType).get("name");
  },

  @computed(
    "userField.editable",
    "userField.required",
    "userField.show_on_profile",
    "userField.show_on_user_card"
  )
  flags(editable, required, showOnProfile, showOnUserCard) {
    const ret = [];
    if (editable) {
      ret.push(I18n.t("admin.user_fields.editable.enabled"));
    }
    if (required) {
      ret.push(I18n.t("admin.user_fields.required.enabled"));
    }
    if (showOnProfile) {
      ret.push(I18n.t("admin.user_fields.show_on_profile.enabled"));
    }
    if (showOnUserCard) {
      ret.push(I18n.t("admin.user_fields.show_on_user_card.enabled"));
    }

    return ret.join(", ");
  },

  actions: {
    save() {
      const buffered = this.buffered;
      const attrs = buffered.getProperties(
        "name",
        "description",
        "field_type",
        "editable",
        "required",
        "show_on_profile",
        "show_on_user_card",
        "options"
      );

      this.userField
        .save(attrs)
        .then(() => {
          this.set("editing", false);
          this.commitBuffer();
        })
        .catch(popupAjaxError);
    },

    edit() {
      this.set("editing", true);
    },

    cancel() {
      const id = this.get("userField.id");
      if (Ember.isEmpty(id)) {
        this.destroyAction(this.userField);
      } else {
        this.rollbackBuffer();
        this.set("editing", false);
      }
    }
  }
});
