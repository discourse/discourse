/**
  A data model for summarizing actions a user has taken, for example liking a post.

  @class ActionSummary
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ActionSummary = Discourse.Model.extend({

  // Description for the action
  description: (function() {
    if (this.get('acted')) {
      return Em.String.i18n('post.actions.by_you_and_others', {
        count: this.get('count') - 1,
        long_form: this.get('actionType.long_form')
      });
    } else {
      return Em.String.i18n('post.actions.by_others', {
        count: this.get('count'),
        long_form: this.get('actionType.long_form')
      });
    }
  }).property('count', 'acted', 'actionType'),

  canAlsoAction: (function() {
    if (this.get('hidden')) return false;
    return this.get('can_act');
  }).property('can_act', 'hidden'),

  // Remove it
  removeAction: function() {
    this.set('acted', false);
    this.set('count', this.get('count') - 1);
    this.set('can_act', true);
    return this.set('can_undo', false);
  },

  // Perform this action
  act: function(opts) {

    // Mark it as acted
    this.set('acted', true);
    this.set('count', this.get('count') + 1);
    this.set('can_act', false);
    this.set('can_undo', true);

    // Add ourselves to the users who liked it if present
    if (this.present('users')) {
      this.users.pushObject(Discourse.get('currentUser'));
    }

    // Create our post action
    var actionSummary = this;
    return $.ajax({
      url: Discourse.getURL("/post_actions"),
      type: 'POST',
      data: {
        id: this.get('post.id'),
        post_action_type_id: this.get('id'),
        message: (opts ? opts.message : void 0) || ""
      }
    }).then(null, function (error) {
      actionSummary.removeAction();
      return $.parseJSON(error.responseText).errors;
    });
  },

  // Undo this action
  undo: function() {
    this.removeAction();

    // Remove our post action
    return $.ajax({
      url: Discourse.getURL("/post_actions/") + (this.get('post.id')),
      type: 'DELETE',
      data: {
        post_action_type_id: this.get('id')
      }
    });
  },

  clearFlags: function() {
    var _this = this;
    return $.ajax({
      url: Discourse.getURL("/post_actions/clear_flags"),
      type: "POST",
      data: {
        post_action_type_id: this.get('id'),
        id: this.get('post.id')
      },
      success: function(result) {
        _this.set('post.hidden', result.hidden);
        return _this.set('count', 0);
      }
    });
  },

  loadUsers: function() {
    var _this = this;
    return $.getJSON(Discourse.getURL("/post_actions/users"), {
      id: this.get('post.id'),
      post_action_type_id: this.get('id')
    }, function(result) {
      _this.set('users', Em.A());
      return result.each(function(u) {
        return _this.get('users').pushObject(Discourse.User.create(u));
      });
    });
  }

});


