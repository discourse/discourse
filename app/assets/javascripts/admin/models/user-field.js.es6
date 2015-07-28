const UserField = Ember.Object.extend({

  destroy() {
    const self = this;
    return new Ember.RSVP.Promise(function(resolve) {
      const id = self.get('id');
      if (id) {
        return Discourse.ajax("/admin/customize/user_fields/" + id, { type: 'DELETE' }).then(function() {
          resolve();
        });
      }
      resolve();
    });
  },

  save(attrs) {
    const id = this.get('id');
    if (!id) {
      return Discourse.ajax("/admin/customize/user_fields", {
        type: "POST",
        data: { user_field: attrs }
      });
    } else {
      return Discourse.ajax("/admin/customize/user_fields/" + id, {
        type: "PUT",
        data: { user_field: attrs }
      });
    }
  }
});

const UserFieldType = Ember.Object.extend({
  name: Discourse.computed.i18n('id', 'admin.user_fields.field_types.%@')
});

UserField.reopenClass({
  findAll() {
    return Discourse.ajax("/admin/customize/user_fields").then(function(result) {
      return result.user_fields.map(function(uf) {
        return UserField.create(uf);
      });
    });
  },

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
