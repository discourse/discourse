var UserField = Ember.Object.extend({
  destroy: function() {
    var self = this;
    return new Ember.RSVP.Promise(function(resolve) {
      var id = self.get('id');
      if (id) {
        return Discourse.ajax("/admin/customize/user_fields/" + id, { type: 'DELETE' }).then(function() {
          resolve();
        });
      }
      resolve();
    });
  },

  save: function(attrs) {
    var id = this.get('id');
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

UserField.reopenClass({
  findAll: function() {
    return Discourse.ajax("/admin/customize/user_fields").then(function(result) {
      return result.user_fields.map(function(uf) {
        return UserField.create(uf);
      });
    });
  },

  fieldTypes: function() {
    if (!this._fieldTypes) {
      this._fieldTypes = [
        Ember.Object.create({id: 'text', name: I18n.t('admin.user_fields.field_types.text') }),
        Ember.Object.create({id: 'confirm', name: I18n.t('admin.user_fields.field_types.confirm') })
      ];
    }

    return this._fieldTypes;
  },

  fieldTypeById: function(id) {
    return this.fieldTypes().findBy('id', id);
  }
});

export default UserField;
