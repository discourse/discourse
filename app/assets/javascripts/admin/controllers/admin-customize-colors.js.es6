export default Ember.ArrayController.extend({
  onlyOverridden: false,

  baseColorScheme: function() {
    return this.get('model').findBy('is_base', true);
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

  filterContent: function() {
    if (!this.get('selectedItem')) { return; }

    if (!this.get('onlyOverridden')) {
      this.set('colors', this.get('selectedItem.colors'));
      return;
    }

    var matches = Em.A();

    _.each(this.get('selectedItem.colors'), function(color){
      if (color.get('overridden')) matches.pushObject(color);
    });

    this.set('colors', matches);
  }.observes('onlyOverridden'),

  updateEnabled: function() {
    var selectedItem = this.get('selectedItem');
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

  actions: {
    selectColorScheme: function(colorScheme) {
      if (this.get('selectedItem')) { this.get('selectedItem').set('selected', false); }
      this.set('selectedItem', colorScheme);
      this.set('colors', colorScheme.get('colors'));
      colorScheme.set('savingStatus', null);
      colorScheme.set('selected', true);
      this.filterContent();
    },

    newColorScheme: function() {
      var newColorScheme = Em.copy(this.get('baseColorScheme'), true);
      newColorScheme.set('name', I18n.t('admin.customize.colors.new_name'));
      this.pushObject(newColorScheme);
      this.send('selectColorScheme', newColorScheme);
      this.set('onlyOverridden', false);
    },

    revert: function(color) {
      color.revert();
    },

    undo: function(color) {
      color.undo();
    },

    toggleEnabled: function() {
      var selectedItem = this.get('selectedItem');
      selectedItem.toggleProperty('enabled');
      selectedItem.save({enabledOnly: true});
      this.updateEnabled();
    },

    save: function() {
      this.get('selectedItem').save();
      this.updateEnabled();
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
