import UserField from 'admin/models/user-field';
import { bufferedProperty } from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Component.extend(bufferedProperty('userField'), {
  editing: Ember.computed.empty('userField.id'),
  classNameBindings: [':user-field'],

  cantMoveUp: propertyEqual('userField', 'firstField'),
  cantMoveDown: propertyEqual('userField', 'lastField'),

  userFieldsDescription: function() {
    return I18n.t('admin.user_fields.description');
  }.property(),

  bufferedFieldType: function() {
    return UserField.fieldTypeById(this.get('buffered.field_type'));
  }.property('buffered.field_type'),

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
    save() {
      const self = this;
      const buffered = this.get('buffered');
      const attrs = buffered.getProperties('name',
                                           'description',
                                           'field_type',
                                           'editable',
                                           'required',
                                           'show_on_profile',
                                           'options');

      this.get('userField').save(attrs).then(function() {
        self.set('editing', false);
        self.commitBuffer();
      }).catch(popupAjaxError);
    },

    moveUp() {
      this.sendAction('moveUpAction', this.get('userField'));
    },

    moveDown() {
      this.sendAction('moveDownAction', this.get('userField'));
    },

    edit() {
      this.set('editing', true);
    },

    destroy() {
      this.sendAction('destroyAction', this.get('userField'));
    },

    cancel() {
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
