import RestModel from 'discourse/models/rest';

const UserField = RestModel.extend();

const UserFieldType = Ember.Object.extend({
  name: Discourse.computed.i18n('id', 'admin.user_fields.field_types.%@')
});

UserField.reopenClass({
  fieldTypes() {
    if (!this._fieldTypes) {
      this._fieldTypes = [
        UserFieldType.create({ id: 'text' }),
        UserFieldType.create({ id: 'confirm' }),
        UserFieldType.create({ id: 'dropdown', hasOptions: true })
      ];
    }

    return this._fieldTypes;
  },

  fieldTypeById(id) {
    return this.fieldTypes().findBy('id', id);
  }
});

export default UserField;
