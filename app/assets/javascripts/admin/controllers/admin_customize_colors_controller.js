/**
  This controller supports interface for creating custom CSS skins in Discourse.

  @class AdminCustomizeColorsController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeColorsController = Ember.ArrayController.extend({

  filter: null,
  onlyOverridden: false,

  baseColorScheme: function() {
    return this.get('model').findBy('id', 1);
  }.property('model.@each.id'),

  baseColors: function() {
    var baseColorsHash = Em.Object.create({});
    _.each(this.get('baseColorScheme.colors'), function(color){
      baseColorsHash.set(color.get('name'), color);
    });
    return baseColorsHash;
  }.property('baseColorScheme'),

  removeSelected: function() {
    this.removeObject(this.get('selectedItem'));
    this.set('selectedItem', null);
  },

  filterContent: Discourse.debounce(function() {
    if (!this.get('selectedItem')) { return; }

    var filter;
    if (this.get('filter')) {
      filter = this.get('filter').toLowerCase();
    }

    if ((filter === undefined || filter.length < 1) && !this.get('onlyOverridden')) {
      this.set('colors', this.get('selectedItem.colors'));
      return;
    }

    var matches = Em.A(), self = this, baseColor;

    _.each(this.get('selectedItem.colors'), function(color){
      if (filter === undefined || filter.length < 1 || color.get('name').toLowerCase().indexOf(filter) > -1) {
        if (self.get('onlyOverridden')) {
          baseColor = self.get('baseColors').get(color.get('name'));
          if (color.get('hex') === baseColor.get('hex') && color.get('opacity') === baseColor.get('opacity')) {
            return;
          }
        }
        matches.pushObject(color);
      }
    });
    this.set('colors', matches);
  }, 250).observes('filter', 'onlyOverridden'),

  actions: {
    selectColorScheme: function(colorScheme) {
      if (this.get('selectedItem')) { this.get('selectedItem').set('selected', false); }
      this.set('selectedItem', colorScheme);
      this.set('colors', colorScheme.get('colors'));
      colorScheme.set('savingStatus', null);
      colorScheme.set('selected', true);
    },

    newColorScheme: function() {
      var newColorScheme = Em.copy(this.get('baseColorScheme'), true);
      newColorScheme.set('name', I18n.t('admin.customize.colors.new_name'));
      this.pushObject(newColorScheme);
      this.send('selectColorScheme', newColorScheme);
    },

    clearFilter: function() {
      this.set('filter', null);
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
