import { ajax } from "discourse/lib/ajax";
import Post from "discourse/models/post";
import computed from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Post.extend({
  @computed
  summary() {
    return _(this.post_actions)
      .groupBy(function(a) {
        return a.post_action_type_id;
      })
      .map(function(v, k) {
        return I18n.t("admin.flags.summary.action_type_" + k, {
          count: v.length
        });
      })
      .join(",");
  },

  @computed("last_revised_at", "post_actions.@each.created_at")
  wasEdited(lastRevisedAt) {
    if (Ember.isEmpty(this.get("last_revised_at"))) {
      return false;
    }
    lastRevisedAt = Date.parse(lastRevisedAt);
    const postActions = this.get("post_actions") || [];
    return postActions.some(postAction => {
      return Date.parse(postAction.created_at) < lastRevisedAt;
    });
  },

  @computed("post_actions")
  hasDisposedBy() {
    return this.get("post_actions").some(action => action.disposed_by);
  },

  @computed("post_actions.@each.name_key")
  flaggedForSpam() {
    return this.get("post_actions").every(action => action.name_key === "spam");
  },

  @computed("post_actions.@each.targets_topic")
  topicFlagged() {
    return _.any(this.get("post_actions"), function(action) {
      return action.targets_topic;
    });
  },

  @computed("post_actions.@each.targets_topic")
  postAuthorFlagged() {
    return _.any(this.get("post_actions"), function(action) {
      return !action.targets_topic;
    });
  },

  @computed("flaggedForSpam")
  canDeleteAsSpammer(flaggedForSpam) {
    return (
      flaggedForSpam &&
      this.get("user.can_delete_all_posts") &&
      this.get("user.can_be_deleted")
    );
  },

  deletePost() {
    if (this.get("post_number") === 1) {
      return ajax("/t/" + this.topic_id, { type: "DELETE", cache: false });
    } else {
      return ajax("/posts/" + this.id, { type: "DELETE", cache: false });
    }
  },

  disagreeFlags() {
    return ajax("/admin/flags/disagree/" + this.id, {
      type: "POST",
      cache: false
    }).catch(popupAjaxError);
  },

  deferFlags(deletePost) {
    const action = () => {
      return ajax("/admin/flags/defer/" + this.id, {
        type: "POST",
        cache: false,
        data: { delete_post: deletePost }
      });
    };

    if (deletePost && this._hasDeletableReplies()) {
      return this._actOnFlagAndDeleteReplies(action);
    } else {
      return action().catch(popupAjaxError);
    }
  },

  agreeFlags(actionOnPost) {
    const action = () => {
      return ajax("/admin/flags/agree/" + this.id, {
        type: "POST",
        cache: false,
        data: { action_on_post: actionOnPost }
      });
    };

    if (actionOnPost === "delete" && this._hasDeletableReplies()) {
      return this._actOnFlagAndDeleteReplies(action);
    } else {
      return action().catch(popupAjaxError);
    }
  },

  _hasDeletableReplies() {
    return this.get("post_number") > 1 && this.get("reply_count") > 0;
  },

  _actOnFlagAndDeleteReplies(action) {
    return new Ember.RSVP.Promise((resolve, reject) => {
      return ajax(`/posts/${this.id}/reply-ids/all.json`)
        .then(replies => {
          const buttons = [];

          buttons.push({
            label: I18n.t("no_value"),
            callback() {
              action()
                .then(resolve)
                .catch(error => {
                  popupAjaxError(error);
                  reject();
                });
            }
          });

          buttons.push({
            label: I18n.t("yes_value"),
            class: "btn-danger",
            callback() {
              Post.deleteMany(replies.map(r => r.id), { deferFlags: true })
                .then(action)
                .then(resolve)
                .catch(error => {
                  popupAjaxError(error);
                  reject();
                });
            }
          });

          bootbox.dialog(
            I18n.t("admin.flags.delete_replies", { count: replies.length }),
            buttons
          );
        })
        .catch(error => {
          popupAjaxError(error);
          reject();
        });
    });
  },

  postHidden: Ember.computed.alias("hidden"),

  deleted: Ember.computed.or("deleted_at", "topic_deleted_at")
});
