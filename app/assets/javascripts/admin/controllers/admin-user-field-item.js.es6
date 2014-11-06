import UserField from 'admin/models/user-field';
import BufferedContent from 'discourse/mixins/buffered-content';

export default Ember.ObjectController.extend(BufferedContent, {
  needs: ['admin-user-fields'],
  editing: Ember.computed.empty('id'),

  fieldName: function() {
    return UserField.fieldTypeById(this.get('field_type')).get('name');
  }.property('field_type'),

  flags: function() {
    var ret = [];
    if (this.get('editable')) {
      ret.push(I18n.t('admin.user_fields.editable.enabled'));
    }
    if (this.get('required')) {
      ret.push(I18n.t('admin.user_fields.required.enabled'));
    }

    return ret.join(', ');
  }.property('editable', 'required'),

  actions: {
    save: function() {
      var self = this;

      var attrs = this.get('buffered').getProperties('name', 'description', 'field_type', 'editable', 'required');

      this.get('model').save(attrs).then(function(res) {
        self.set('model.id', res.user_field.id);
        self.set('editing', false);
        self.commitBuffer();
      }).catch(function(e) {
        var msg = I18n.t("generic_error");
        if (e.responseJSON && e.responseJSON.errors) {
          msg = I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')});
        }
        bootbox.alert(msg);
      });
    },

    edit: function() {
      this.set('editing', true);
    },

    destroy: function() {
      this.get('controllers.admin-user-fields').send('destroy', this.get('model'));
    },

    cancel: function() {
      var id = this.get('id');
      if (Ember.empty(id)) {
        this.get('controllers.admin-user-fields').send('destroy', this.get('model'));
      } else {
        this.rollbackBuffer();
        this.set('editing', false);
      }
    }
  }
});
