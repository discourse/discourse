import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { i18n } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";

export default class UserField extends RestModel {
  static fieldTypes() {
    if (!this._fieldTypes) {
      this._fieldTypes = [
        UserFieldType.create({ id: "text" }),
        UserFieldType.create({ id: "confirm" }),
        UserFieldType.create({ id: "dropdown", hasOptions: true }),
        UserFieldType.create({ id: "multiselect", hasOptions: true }),
      ];
    }

    return this._fieldTypes;
  }

  static fieldTypeById(id) {
    return this.fieldTypes().findBy("id", id);
  }

  @tracked field_type;
  @tracked editable;
  @tracked show_on_profile;
  @tracked show_on_user_card;
  @tracked searchable;

  get fieldTypeName() {
    return UserField.fieldTypes().find((ft) => ft.id === this.field_type).name;
  }
}

class UserFieldType extends EmberObject {
  @i18n("id", "admin.user_fields.field_types.%@") name;
}
