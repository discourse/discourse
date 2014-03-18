/**
  This is the itemController for `Discourse.AdminBadgesController`. Its main purpose
  is to indicate which badge was selected.

  @class AdminBadgeController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/

Discourse.AdminBadgeController = Discourse.ObjectController.extend({
  /**
    Whether this badge has been selected.

    @property selected
    @type {Boolean}
  **/
  selected: Discourse.computed.propertyEqual('model.name', 'parentController.selectedItem.name')
});
