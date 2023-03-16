import EmberObject from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse/lib/computed";

class UserField extends RestModel {}

class UserFieldType extends EmberObject {
  @i18n("id", "admin.user_fields.field_types.%@") name;
}

UserField.reopenClass({
  fieldTypes() {
    if (!this._fieldTypes) {
      this._fieldTypes = [
        UserFieldType.create({ id: "text" }),
        UserFieldType.create({ id: "confirm" }),
        UserFieldType.create({ id: "dropdown", hasOptions: true }),
        UserFieldType.create({ id: "multiselect", hasOptions: true }),
      ];
    }

    return this._fieldTypes;
  },

  fieldTypeById(id) {
    return this.fieldTypes().findBy("id", id);
  },
});

export default UserField;
