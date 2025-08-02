import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import RestModel from "discourse/models/rest";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

export default class CustomReaction extends RestModel {
  static toggle(post, reactionId) {
    return ajax(
      `/discourse-reactions/posts/${post.id}/custom-reactions/${reactionId}/toggle.json`,
      { type: "PUT" }
    ).then((result) => {
      post.appEvents.trigger("discourse-reactions:reaction-toggled", {
        post: result,
        reaction: result.current_user_reaction,
      });
    });
  }

  static findReactions(url, username, opts) {
    opts = opts || {};
    const data = { username };

    if (opts.beforeReactionUserId) {
      data.before_reaction_user_id = opts.beforeReactionUserId;
    }

    if (opts.beforeLikeId) {
      data.before_like_id = opts.beforeLikeId;
    }

    if (opts.includeLikes) {
      data.include_likes = opts.includeLikes;
    }

    if (opts.actingUsername) {
      data.acting_username = opts.actingUsername;
    }

    return ajax(`/discourse-reactions/posts/${url}.json`, {
      data,
    }).then((reactions) => {
      return reactions.map((reaction) => {
        reaction.user = User.create(reaction.user);
        reaction.topic = Topic.create(reaction.post.topic);
        reaction.post_user = User.create(reaction.post.user);
        reaction.category = Category.findById(reaction.post.category_id);

        const postAttrs = { ...reaction.post };
        delete postAttrs.url; // Auto-calculated by Model implementation

        reaction.post = Post.create(postAttrs);
        return EmberObject.create(reaction);
      });
    });
  }

  static findReactionUsers(postId, opts) {
    opts = opts || {};
    const data = {};

    if (opts.reactionValue) {
      data.reaction_value = opts.reactionValue;
    }

    return ajax(`/discourse-reactions/posts/${postId}/reactions-users.json`, {
      data,
    });
  }

  init() {
    super.init(...arguments);
    this.__type = "discourse-reactions-custom-reaction";
  }
}
