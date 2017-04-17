import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  @computed("model.colors","onlyOverridden")
  colors(allColors, onlyOverridden) {
    if (onlyOverridden) {
      return allColors.filter(color => color.get("overridden"));
    } else {
      return allColors;
    }
  },

  actions: {

    revert: function(color) {
      color.revert();
    },

    undo: function(color) {
      color.undo();
    },

    copy() {
      var newColorScheme = Em.copy(this.get('model'), true);
      newColorScheme.set('name', I18n.t('admin.customize.colors.copy_name_prefix') + ' ' + this.get('model.name'));
      newColorScheme.save().then(()=>{
        this.get('allColors').pushObject(newColorScheme);
        this.replaceRoute('adminCustomize.colors.show', newColorScheme);
      });
    },

    save: function() {
      this.get('model').save();
    },

    destroy: function() {

      return bootbox.confirm(I18n.t("admin.customize.colors.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), result => {
        if (result) {
          this.get('model').destroy().then(()=>{
            this.get('allColors').removeObject(this.get('model'));
            this.replaceRoute('adminCustomize.colors');
          });
        }
      });
    }
  }
});
