/**
  A data model representing a group of UserActions

  @class UserActionGroup
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActionGroup = Discourse.Model.extend({
  push: function(item) {
    if (!this.items) {
      this.items = [];
    }
    return this.items.push(item);
  }
});


