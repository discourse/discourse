/**
  Provide a nice GUI for a pipe-delimited list in the site settings.

  @param settingValue is a reference to SiteSetting.value.

  @class Discourse.ListSettingComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
 **/
Discourse.ListSettingComponent = Ember.Component.extend({
  layoutName: 'components/list-setting',

  init: function() {
    this._super();
    this.on("focusOut", this.uncacheValue);
    this.set('children', []);
  },

  canAddNew: true,

  readValues: function() {
    return this.get('settingValue').split('|');
  }.property('settingValue'),

  /**
    Transfer the debounced value into the settingValue parameter.

    This will cause a redraw of the child textboxes.

    @param newFocus {Number|undefined} Which list index to focus on next, or undefined to not refocus
  **/
  uncacheValue: function(newFocus) {
    var oldValue = this.get('settingValue'),
        newValue = this.get('settingValueCached'),
        self = this;

    if (newValue !== undefined && newValue !== oldValue) {
      this.set('settingValue', newValue);
    }

    if (newFocus !== undefined && newFocus > 0) {
      Em.run.schedule('afterRender', function() {
        var children = self.get('children');
        if (newFocus < children.length) {
          $(children[newFocus].get('element')).focus();
        } else if (newFocus === children.length) {
          $(self.get('element')).children().children('.list-add-value').focus();
        }
      });
    }
  },

  setItemValue: function(index, item) {
    var values = this.get('readValues');
    values[index] = item;

    // Remove blank items
    values = values.filter(function(s) { return s !== ''; });
    this.setProperties({
      settingValueCached: values.join('|'),
      canAddNew: true
    });
  },

  actions: {
    addNewItem: function() {
      var newValue = this.get('settingValue') + '|';
      this.setProperties({
        settingValue: newValue,
        settingValueCached: newValue,
        canAddNew: false
      });

      var self = this;
      Em.run.schedule('afterRender', function() {
        var children = self.get('children');
        $(children[children.length - 1].get('element')).focus();
      });
    }
  }
});
