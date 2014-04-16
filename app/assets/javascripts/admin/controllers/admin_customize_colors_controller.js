/**
  This controller supports interface for creating custom CSS skins in Discourse.

  @class AdminCustomizeColorsController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeColorsController = Ember.ArrayController.extend({

  baseColorScheme: function() {
    return this.get('model').findBy('id', 1);
  }.property('model.@each.id'),

  removeSelected: function() {
    this.removeObject(this.get('selectedItem'));
    this.set('selectedItem', null);
  },

  actions: {
    selectColorScheme: function(colorScheme) {
      if (this.get('selectedItem')) { this.get('selectedItem').set('selected', false); }
      this.set('selectedItem', colorScheme);
      colorScheme.set('savingStatus', null);
      colorScheme.set('selected', true);
    },

    newColorScheme: function() {
      var newColorScheme = Em.copy(this.get('baseColorScheme'), true);
      newColorScheme.set('name', I18n.t('admin.customize.colors.new_name'));
      this.pushObject(newColorScheme);
      this.send('selectColorScheme', newColorScheme);
    },

    undo: function(color) {
      color.undo();
    },

    save: function() {
      var selectedItem = this.get('selectedItem');
      selectedItem.save();
      if (selectedItem.get('enabled')) {
        this.get('model').forEach(function(c) {
          if (c !== selectedItem) {
            c.set('enabled', false);
            c.startTrackingChanges();
            c.notifyPropertyChange('description');
          }
        });
      }
    },

    copy: function(colorScheme) {
      var newColorScheme = Em.copy(colorScheme, true);
      newColorScheme.set('name', I18n.t('admin.customize.colors.copy_name_prefix') + ' ' + colorScheme.get('name'));
      this.pushObject(newColorScheme);
      this.send('selectColorScheme', newColorScheme);
    },

    destroy: function() {
      var self = this,
          item = self.get('selectedItem');

      return bootbox.confirm(I18n.t("admin.customize.colors.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          if (item.get('newRecord')) {
            self.removeSelected();
          } else {
            item.destroy().then(function(){ self.removeSelected(); });
          }
        }
      });
    }
  }

});
