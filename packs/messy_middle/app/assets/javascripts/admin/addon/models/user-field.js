import EmberObject from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse/lib/computed";

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
}

class UserFieldType extends EmberObject {
  @i18n("id", "admin.user_fields.field_types.%@") name;
}
