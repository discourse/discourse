import RestModel from 'discourse/models/rest';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default RestModel.extend({

  canToggle: function() {
    return this.get('can_undo') || this.get('can_act');
  }.property('can_undo', 'can_act'),

  // Remove it
  removeAction: function() {
    this.setProperties({
      acted: false,
      count: this.get('count') - 1,
      can_act: true,
      can_undo: false
    });
  },

  togglePromise(post) {
    if (!this.get('acted')) {
      return this.act(post).then(() => true);
    }
    return this.undo(post).then(() => false);
  },

  toggle(post) {
    if (!this.get('acted')) {
      this.act(post);
      return true;
    } else {
      this.undo(post);
      return false;
    }
  },

  // Perform this action
  act(post, opts) {

    if (!opts) opts = {};

    const action = this.get('actionType.name_key');

    // Mark it as acted
    this.setProperties({
      acted: true,
      count: this.get('count') + 1,
      can_act: false,
      can_undo: true
    });

    if (action === 'notify_moderators' || action === 'notify_user') {
      this.set('can_undo',false);
      this.set('can_defer_flags',false);
    }

    // Create our post action
    const self = this;
    return Discourse.ajax("/post_actions", {
      type: 'POST',
      data: {
        id: this.get('flagTopic') ? this.get('flagTopic.id') : post.get('id'),
        post_action_type_id: this.get('id'),
        message: opts.message,
        take_action: opts.takeAction,
        flag_topic: this.get('flagTopic') ? true : false
      }
    }).then(function(result) {
      if (!self.get('flagTopic')) {
        return post.updateActionsSummary(result);
      }
    }).catch(function(error) {
      popupAjaxError(error);
      self.removeAction(post);
    });
  },

  // Undo this action
  undo(post) {
    this.removeAction(post);

    // Remove our post action
    return Discourse.ajax("/post_actions/" + post.get('id'), {
      type: 'DELETE',
      data: { post_action_type_id: this.get('id') }
    }).then(result => post.updateActionsSummary(result));
  },

  deferFlags(post) {
    return Discourse.ajax("/post_actions/defer_flags", {
      type: "POST",
      data: { post_action_type_id: this.get("id"), id: post.get('id') }
    }).then(() => this.set('count', 0));
  }
});
