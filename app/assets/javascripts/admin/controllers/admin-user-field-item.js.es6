import UserField from 'admin/models/user-field';
import BufferedContent from 'discourse/mixins/buffered-content';

export default Ember.ObjectController.extend(BufferedContent, {
  needs: ['admin-user-fields'],
  editing: Ember.computed.empty('id'),

  fieldName: function() {
    return UserField.fieldTypeById(this.get('field_type')).get('name');
  }.property('field_type'),

  actions: {
    save: function() {
      var self = this;

      var attrs = this.get('buffered').getProperties('name', 'field_type', 'editable');

      this.get('model').save(attrs).then(function(res) {
        self.set('model.id', res.user_field.id);
        self.set('editing', false);
        self.commitBuffer();
      }).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
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
