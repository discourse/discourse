import { bufferedProperty } from 'discourse/mixins/buffered-content';
import UserField from 'admin/models/user-field';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend(bufferedProperty('userField'), {
  editing: Ember.computed.empty('userField.id'),
  classNameBindings: [':user-field'],

  _focusOnEdit: function() {
    if (this.get('editing')) {
      Ember.run.scheduleOnce('afterRender', this, '_focusName');
    }
  }.observes('editing').on('didInsertElement'),

  _focusName: function() {
    $('.user-field-name').select();
  },

  fieldName: function() {
    return UserField.fieldTypeById(this.get('userField.field_type')).get('name');
  }.property('userField.field_type'),

  flags: function() {
    const ret = [];
    if (this.get('userField.editable')) {
      ret.push(I18n.t('admin.user_fields.editable.enabled'));
    }
    if (this.get('userField.required')) {
      ret.push(I18n.t('admin.user_fields.required.enabled'));
    }
    if (this.get('userField.show_on_profile')) {
      ret.push(I18n.t('admin.user_fields.show_on_profile.enabled'));
    }

    return ret.join(', ');
  }.property('userField.editable', 'userField.required', 'userField.show_on_profile'),

  actions: {
    save: function() {
      const self = this;
      const attrs = this.get('buffered').getProperties('name', 'description', 'field_type', 'editable', 'required', 'show_on_profile');

      this.get('userField').save(attrs).then(function(res) {
        self.set('userField.id', res.user_field.id);
        self.set('editing', false);
        self.commitBuffer();
      }).catch(popupAjaxError);
    },

    edit: function() {
      this.set('editing', true);
    },

    destroy: function() {
      this.sendAction('destroyAction', this.get('userField'));
    },

    cancel: function() {
      const id = this.get('userField.id');
      if (Ember.isEmpty(id)) {
        this.sendAction('destroyAction', this.get('userField'));
      } else {
        this.rollbackBuffer();
        this.set('editing', false);
      }
    }
  }
});
