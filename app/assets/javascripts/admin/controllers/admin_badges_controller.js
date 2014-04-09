/**
  This controller supports the interface for dealing with badges.

  @class AdminBadgesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminBadgesController = Ember.ArrayController.extend({
  itemController: 'adminBadge',

  /**
    Show the displayName only if it is different from the name.

    @property showDisplayName
    @type {Boolean}
  **/
  showDisplayName: Discourse.computed.propertyNotEqual('selectedItem.name', 'selectedItem.displayName'),

  /**
    We don't allow setting a description if a translation for the given badge name
    exists.

    @property canEditDescription
    @type {Boolean}
  **/
  canEditDescription: Em.computed.none('selectedItem.translatedDescription'),

  /**
    Disable saving if the currently selected item is being saved.

    @property disableSave
    @type {Boolean}
  **/
  disableSave: Em.computed.alias('selectedItem.saving'),

  actions: {

    /**
      Create a new badge and select it.

      @method newBadge
    **/
    newBadge: function() {
      var badge = Discourse.Badge.create({
        name: I18n.t('admin.badges.new_badge')
      });
      this.pushObject(badge);
      this.send('selectBadge', badge);
    },

    /**
      Select a particular badge.

      @method selectBadge
      @param {Discourse.Badge} badge The badge to be selected
    **/
    selectBadge: function(badge) {
      this.set('selectedItem', badge);
    },

    /**
      Save the selected badge.

      @method save
    **/
    save: function() {
      if (!this.get('disableSave')) {
        this.get('selectedItem').save();
      }
    },

    /**
      Confirm before destroying the selected badge.

      @method destroy
    **/
    destroy: function() {
      var self = this;
      return bootbox.confirm(I18n.t("admin.badges.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          var selected = self.get('selectedItem');
          selected.destroy().then(function() {
            // Success.
            self.set('selectedItem', null);
            self.get('model').removeObject(selected);
          }, function() {
            // Failure.
            bootbox.alert(I18n.t('generic_error'));
          });
        }
      });
    }

  }

});
