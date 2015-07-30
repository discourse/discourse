import { popupAjaxError } from 'discourse/lib/ajax-error';

const MAX_FIELDS = 20;

export default Ember.Controller.extend({
  fieldTypes: null,
  createDisabled: Em.computed.gte('model.length', MAX_FIELDS),

  arrangedContent: function() {
    return Ember.ArrayProxy.extend(Ember.SortableMixin).create({
      sortProperties: ['position'],
      content: this.get('model')
    });
  }.property('model'),

  actions: {
    createField() {
      const f = this.store.createRecord('user-field', { field_type: 'text', position: MAX_FIELDS });
      this.get('model').pushObject(f);
    },

    moveUp(f) {
      const idx = this.get('arrangedContent').indexOf(f);
      if (idx) {
        const prev = this.get('arrangedContent').objectAt(idx-1);
        const prevPos = prev.get('position');

        prev.update({ position: f.get('position') });
        f.update({ position: prevPos });
      }
    },

    moveDown(f) {
      const idx = this.get('arrangedContent').indexOf(f);
      if (idx > -1) {
        const next = this.get('arrangedContent').objectAt(idx+1);
        const nextPos = next.get('position');

        next.update({ position: f.get('position') });
        f.update({ position: nextPos });
      }
    },

    destroy(f) {
      const model = this.get('model');

      // Only confirm if we already been saved
      if (f.get('id')) {
        bootbox.confirm(I18n.t("admin.user_fields.delete_confirm"), function(result) {
          if (result) {
            f.destroyRecord().then(function() {
              model.removeObject(f);
            }).catch(popupAjaxError);
          }
        });
      } else {
        model.removeObject(f);
      }
    }
  }
});
