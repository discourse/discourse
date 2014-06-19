/**
  This is the itemController for `Discourse.AdminBadgesController`. Its main purpose
  is to indicate which badge was selected.

  @class AdminBadgeController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/

var RESERVED_BADGE_COUNT = 100;

Discourse.AdminBadgeController = Discourse.ObjectController.extend({
  /**
    Whether this badge has been selected.

    @property selected
    @type {Boolean}
  **/
  selected: Discourse.computed.propertyEqual('model.name', 'parentController.selectedItem.name'),

  /**
    Show the displayName only if it is different from the name.

    @property showDisplayName
    @type {Boolean}
  **/
  showDisplayName: Discourse.computed.propertyNotEqual('selectedItem.name', 'selectedItem.displayName'),

  /**
    Don't allow editing if this is a system badge.

    @property readOnly
    @type {Boolean}
  **/
  readOnly: Ember.computed.lt('model.id', RESERVED_BADGE_COUNT)
});
