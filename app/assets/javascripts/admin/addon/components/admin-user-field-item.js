import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import { i18n, propertyEqual } from "discourse/lib/computed";
import Component from "@ember/component";
import I18n from "I18n";
import UserField from "admin/models/user-field";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import { empty } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend(bufferedProperty("userField"), {
  editing: empty("userField.id"),
  classNameBindings: [":user-field"],

  cantMoveUp: propertyEqual("userField", "firstField"),
  cantMoveDown: propertyEqual("userField", "lastField"),

  userFieldsDescription: i18n("admin.user_fields.description"),

  @discourseComputed("buffered.field_type")
  bufferedFieldType(fieldType) {
    return UserField.fieldTypeById(fieldType);
  },

  @on("didInsertElement")
  @observes("editing")
  _focusOnEdit() {
    if (this.editing) {
      scheduleOnce("afterRender", this, "_focusName");
    }
  },

  _focusName() {
    $(".user-field-name").select();
  },

  @discourseComputed("userField.field_type")
  fieldName(fieldType) {
    return UserField.fieldTypeById(fieldType).get("name");
  },

  @discourseComputed(
    "userField.{editable,required,show_on_profile,show_on_user_card,searchable}"
  )
  flags(userField) {
    const ret = [];
    if (userField.editable) {
      ret.push(I18n.t("admin.user_fields.editable.enabled"));
    }
    if (userField.required) {
      ret.push(I18n.t("admin.user_fields.required.enabled"));
    }
    if (userField.showOnProfile) {
      ret.push(I18n.t("admin.user_fields.show_on_profile.enabled"));
    }
    if (userField.showOnUserCard) {
      ret.push(I18n.t("admin.user_fields.show_on_user_card.enabled"));
    }
    if (userField.searchable) {
      ret.push(I18n.t("admin.user_fields.searchable.enabled"));
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
        "searchable",
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
      if (isEmpty(id)) {
        this.destroyAction(this.userField);
      } else {
        this.rollbackBuffer();
        this.set("editing", false);
      }
    },
  },
});
