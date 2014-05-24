/**
  This controller supports the interface for dealing with badges.

  @class AdminBadgesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminBadgesController = Ember.ArrayController.extend({
  itemController: 'adminBadge',
  queryParams: ['badgeId'],
  badgeId: Em.computed.alias('selectedId'),

  /**
    ID of the currently selected badge.

    @property selectedId
    @type {Integer}
  **/
  selectedId: null,

  /**
    Badge that is currently selected.

    @property selectedItem
    @type {Discourse.Badge}
  **/
  selectedItem: function() {
    if (this.get('selectedId') === undefined || this.get('selectedId') === "undefined") {
      // New Badge
      return this.get('newBadge');
    } else {
      // Existing Badge
      var selectedId = parseInt(this.get('selectedId'));
      return this.get('model').filter(function(badge) {
        return parseInt(badge.get('id')) === selectedId;
      })[0];
    }
  }.property('selectedId', 'newBadge'),

  /**
    Unsaved badge, if one exists.

    @property newBadge
    @type {Discourse.Badge}
  **/
  newBadge: function() {
    return this.get('model').filter(function(badge) {
      return badge.get('id') === undefined;
    })[0];
  }.property('model.@each.id'),

  /**
    Whether a new unsaved badge exists.

    @property newBadgeExists
    @type {Discourse.Badge}
  **/
  newBadgeExists: Em.computed.notEmpty('newBadge'),

  /**
    We don't allow setting a description if a translation for the given badge
    name exists.

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
    createNewBadge: function() {
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
      this.set('selectedId', badge.get('id'));
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
      // Delete immediately if the selected badge is new.
      if (!this.get('selectedItem.id')) {
        this.get('model').removeObject(this.get('selectedItem'));
        this.set('selectedId', null);
        return;
      }

      var self = this;
      return bootbox.confirm(I18n.t("admin.badges.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          var selected = self.get('selectedItem');
          selected.destroy().then(function() {
            // Success.
            self.set('selectedId', null);
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
