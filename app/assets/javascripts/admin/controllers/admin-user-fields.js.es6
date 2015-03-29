import UserField from 'admin/models/user-field';

export default Ember.ArrayController.extend({
  fieldTypes: null,
  createDisabled: Em.computed.gte('model.length', 3),

  userFieldsDescription: function() {
    return I18n.t('admin.user_fields.description');
  }.property(),

  userFieldsName: function() {
    return I18n.t('admin.user_fields.name');
  }.property(),

  _performDestroy: function(f, model) {
    return f.destroy().then(function() {
      model.removeObject(f);
    });
  },

  actions: {
    createField: function() {
      this.pushObject(UserField.create({ field_type: 'text' }));
    },

    destroy: function(f) {
      var model = this.get('model'),
          self = this;

      // Only confirm if we already been saved
      if (f.get('id')) {
        bootbox.confirm(I18n.t("admin.user_fields.delete_confirm"), function(result) {
          if (result) { self._performDestroy(f, model); }
        });
      } else {
        self._performDestroy(f, model);
      }
    }
  }
});
