import { tracked } from "@glimmer/tracking";
import EmberObject, { get } from "@ember/object";
import { alias, and, equal, not, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { resolveShareUrl } from "discourse/helpers/share-url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { propertyEqual } from "discourse/lib/computed";
import { cook } from "discourse/lib/text";
import { fancyTitle } from "discourse/lib/topic-fancy-title";
import { defineTrackedProperty } from "discourse/lib/tracked-tools";
import { userPath } from "discourse/lib/url";
import { postUrl } from "discourse/lib/utilities";
import ActionSummary from "discourse/models/action-summary";
import Composer from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const pluginTrackedProperties = new Set();
const trackedPropertiesForPostUpdate = new Set();

/**
 * @internal
 * Adds a tracked property to the post model.
 *
 * Intended to be used only in the plugin API.
 *
 * @param {string} propertyKey - The key of the property to track.
 */
export function _addTrackedPostProperty(propertyKey) {
  pluginTrackedProperties.add(propertyKey);
}

/**
 * Clears all tracked properties added using the API
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function clearAddedTrackedPostProperties() {
  pluginTrackedProperties.clear();
}

/**
 * Decorator to mark a property as post property as tracked.
 *
 * It extends the standard Ember @tracked behavior to also keep track of the fields
 * that need to be copied when using `post.updateFromPost`.
 *
 * @param {Object} target - The target object.
 * @param {string} propertyKey - The key of the property to track.
 * @param {PropertyDescriptor} descriptor - The property descriptor.
 * @returns {PropertyDescriptor} The updated property descriptor.
 */
function trackedPostProperty(target, propertyKey, descriptor) {
  trackedPropertiesForPostUpdate.add(propertyKey);
  return tracked(target, propertyKey, descriptor);
}

export default class Post extends RestModel {
  static munge(json) {
    json.likeAction ??= null;
    if (json.actions_summary) {
      const lookup = EmberObject.create();

      // this area should be optimized, it is creating way too many objects per post
      json.actions_summary = json.actions_summary.map((a) => {
        a.actionType = Site.current().postActionTypeById(a.id);
        a.count = a.count || 0;
        const actionSummary = ActionSummary.create(a);
        lookup[a.actionType.name_key] = actionSummary;

        if (a.actionType.name_key === "like") {
          json.likeAction = actionSummary;
        }
        return actionSummary;
      });

      json.actionByName = lookup;
    }

    if (json && json.reply_to_user) {
      json.reply_to_user = User.create(json.reply_to_user);
    }

    return json;
  }

  static updateBookmark(postId, bookmarked) {
    return ajax(`/posts/${postId}/bookmark`, {
      type: "PUT",
      data: { bookmarked },
    });
  }

  static destroyBookmark(postId) {
    return ajax(`/posts/${postId}/bookmark`, {
      type: "DELETE",
    });
  }

  static deleteMany(post_ids, { agreeWithFirstReplyFlag = true } = {}) {
    return ajax("/posts/destroy_many", {
      type: "DELETE",
      data: { post_ids, agree_with_first_reply_flag: agreeWithFirstReplyFlag },
    });
  }

  static mergePosts(post_ids) {
    return ajax("/posts/merge_posts", {
      type: "PUT",
      data: { post_ids },
    }).catch(popupAjaxError);
  }

  static loadRevision(postId, version) {
    return ajax(`/posts/${postId}/revisions/${version}.json`).then((result) => {
      result.categories?.forEach((c) => Site.current().updateCategory(c));
      return EmberObject.create(result);
    });
  }

  static hideRevision(postId, version) {
    return ajax(`/posts/${postId}/revisions/${version}/hide`, {
      type: "PUT",
    });
  }

  static permanentlyDeleteRevisions(postId) {
    return ajax(`/posts/${postId}/revisions/permanently_delete`, {
      type: "DELETE",
    });
  }

  static showRevision(postId, version) {
    return ajax(`/posts/${postId}/revisions/${version}/show`, {
      type: "PUT",
    });
  }

  static loadRawEmail(postId) {
    return ajax(`/posts/${postId}/raw-email.json`);
  }

  @service currentUser;
  @service site;
  @service store;

  // Use @trackedPostProperty here instead of Glimmer's @tracked because we need to know which properties are tracked
  // in order to correctly update the post in the updateFromPost method. Currently this is not possible using only
  // the standard tracked method because these properties are added to the class prototype and are not enumarated by
  // object.keys().
  // See https://github.com/emberjs/ember.js/issues/18220
  @trackedPostProperty bookmarked;
  @trackedPostProperty can_delete;
  @trackedPostProperty can_edit;
  @trackedPostProperty can_permanently_delete;
  @trackedPostProperty can_recover;
  @trackedPostProperty deleted_at;
  @trackedPostProperty likeAction;
  @trackedPostProperty post_type;
  @trackedPostProperty user_deleted;
  @trackedPostProperty user_id;
  @trackedPostProperty yours;

  customShare = null;

  @alias("can_edit") canEdit; // for compatibility with existing code
  @equal("trust_level", 0) new_user;
  @equal("post_number", 1) firstPost;
  @or("deleted_at", "deletedViaTopic") deleted;
  @not("deleted") notDeleted;
  @propertyEqual("topic.details.created_by.id", "user_id") topicOwner;
  @alias("topic.details.created_by.id") topicCreatedById;

  // Posts can show up as deleted if the topic is deleted
  @and("firstPost", "topic.deleted_at") deletedViaTopic;

  constructor() {
    super(...arguments);

    // adds tracked properties defined by plugin to the instance
    pluginTrackedProperties.forEach((propertyKey) => {
      defineTrackedProperty(this, propertyKey);
    });
  }

  @discourseComputed("url", "customShare")
  shareUrl(url) {
    return this.customShare || resolveShareUrl(url, this.currentUser);
  }

  @discourseComputed("name", "username")
  showName(name, username) {
    return name && name !== username && this.siteSettings.display_name_on_posts;
  }

  @discourseComputed("firstPost", "deleted_by", "topic.deleted_by")
  postDeletedBy(firstPost, deletedBy, topicDeletedBy) {
    return firstPost ? topicDeletedBy : deletedBy;
  }

  @discourseComputed("firstPost", "deleted_at", "topic.deleted_at")
  postDeletedAt(firstPost, deletedAt, topicDeletedAt) {
    return firstPost ? topicDeletedAt : deletedAt;
  }

  @discourseComputed("post_number", "topic_id", "topic.slug")
  url(post_number, topic_id, topicSlug) {
    return postUrl(
      topicSlug || this.topic_slug,
      topic_id || this.get("topic.id"),
      post_number
    );
  }

  // Don't drop the /1
  @discourseComputed("post_number", "url")
  urlWithNumber(postNumber, baseUrl) {
    return postNumber === 1 ? `${baseUrl}/1` : baseUrl;
  }

  @discourseComputed("username")
  usernameUrl(username) {
    return userPath(username);
  }

  updatePostField(field, value) {
    const data = {};
    data[field] = value;

    return ajax(`/posts/${this.id}/${field}`, { type: "PUT", data })
      .then(() => this.set(field, value))
      .catch(popupAjaxError);
  }

  @discourseComputed("link_counts.@each.internal")
  internalLinks() {
    if (isEmpty(this.link_counts)) {
      return null;
    }

    return this.link_counts.filterBy("internal").filterBy("title");
  }

  @discourseComputed("actions_summary.@each.can_act")
  flagsAvailable() {
    // TODO: Investigate why `this.site` is sometimes null when running
    // Search - Search with context
    if (!this.site) {
      return [];
    }

    return this.site.flagTypes.filter((item) =>
      this.get(`actionByName.${item.name_key}.can_act`)
    );
  }

  @discourseComputed(
    "siteSettings.use_pg_headlines_for_excerpt",
    "topic_title_headline"
  )
  useTopicTitleHeadline(enabled, title) {
    return enabled && title;
  }

  @discourseComputed("topic_title_headline")
  topicTitleHeadline(title) {
    return fancyTitle(title, this.siteSettings.support_mixed_text_direction);
  }

  get canBookmark() {
    return !!this.currentUser;
  }

  get canDelete() {
    return (
      this.can_delete &&
      !this.deleted_at &&
      this.currentUser &&
      (this.currentUser.staff || !this.user_deleted)
    );
  }

  get canDeleteTopic() {
    return this.firstPost && !this.deleted && this.topic.details.can_delete;
  }

  get canEditStaffNotes() {
    return !!this.topic.details.can_edit_staff_notes;
  }

  get canFlag() {
    return !this.topic.deleted && !isEmpty(this.flagsAvailable);
  }

  get canManage() {
    return this.currentUser?.canManageTopic;
  }

  get canPermanentlyDelete() {
    return (
      this.deleted &&
      (this.firstPost
        ? this.topic.details.can_permanently_delete
        : this.can_permanently_delete)
    );
  }

  get canPublishPage() {
    return this.firstPost && !!this.topic.details.can_publish_page;
  }

  get canRecover() {
    return this.deleted && this.can_recover;
  }

  get isRecovering() {
    return !this.deleted && this.can_recover;
  }

  get canRecoverTopic() {
    return this.firstPost && this.deleted && this.topic.details.can_recover;
  }

  get isRecoveringTopic() {
    return this.firstPost && !this.deleted && this.topic.details.can_recover;
  }

  get canToggleLike() {
    return !!this.likeAction?.get("canToggle");
  }

  get filteredRepliesPostNumber() {
    return this.topic.get("postStream.filterRepliesToPostNumber");
  }

  get isWhisper() {
    return this.post_type === this.site.post_types.whisper;
  }

  get isModeratorAction() {
    return this.post_type === this.site.post_types.moderator_action;
  }

  get liked() {
    return !!this.likeAction?.get("acted");
  }

  get likeCount() {
    return this.likeAction?.get("count");
  }

  /**
   * Show a "Flag to delete" message if not staff and you can't otherwise delete it.
   */
  get showFlagDelete() {
    return (
      !this.canDelete &&
      this.yours &&
      this.canFlag &&
      this.currentUser &&
      !this.currentUser.staff
    );
  }

  get showLike() {
    if (
      !this.currentUser ||
      (this.topic?.get("archived") && this.user_id !== this.currentUser.id)
    ) {
      return true;
    }

    return this.likeAction && (this.liked || this.canToggleLike);
  }

  async ensureTopicLoaded() {
    if (this.topic) {
      return Promise.resolve();
    }

    const topic = await Topic.find(this.topic_id, {});
    this.set("topic", topic);
  }

  afterUpdate(res) {
    if (res.category) {
      this.site.updateCategory(res.category);
    }
  }

  updateProperties() {
    return {
      post: { raw: this.raw, edit_reason: this.editReason },
      image_sizes: this.imageSizes,
    };
  }

  createProperties() {
    // composer only used once, defer the dependency
    const data = this.getProperties(Composer.serializedFieldsForCreate());
    data.reply_to_post_number = this.reply_to_post_number;
    data.image_sizes = this.imageSizes;

    const metaData = this.metaData;

    // Put the metaData into the request
    if (metaData) {
      data.meta_data = {};
      Object.keys(metaData).forEach(
        (key) => (data.meta_data[key] = metaData[key])
      );
    }

    return data;
  }

  // Expands the first post's content, if embedded and shortened.
  expand() {
    return ajax(`/posts/${this.id}/expand-embed`).then((post) => {
      this.set(
        "cooked",
        `<section class="expanded-embed">${post.cooked}</section>`
      );
    });
  }

  // Recover a deleted post
  recover() {
    const initProperties = this.getProperties(
      "deleted_at",
      "deleted_by",
      "user_deleted",
      "can_delete"
    );

    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      user_deleted: false,
      can_delete: false,
    });

    return ajax(`/posts/${this.id}/recover`, {
      type: "PUT",
    })
      .then((data) => {
        this.setProperties({
          cooked: data.cooked,
          raw: data.raw,
          user_deleted: false,
          can_delete: true,
          version: data.version,
        });
      })
      .catch((error) => {
        popupAjaxError(error);
        this.setProperties(initProperties);
      });
  }

  /**
   Changes the state of the post to be deleted. Does not call the server, that should be
   done elsewhere.
   **/
  setDeletedState(deletedBy) {
    let promise;
    this.set("oldCooked", this.cooked);

    // Moderators can delete posts. Users can only trigger a deleted at message, unless delete_removed_posts_after is 0.
    if (deletedBy.staff || this.siteSettings.delete_removed_posts_after === 0) {
      this.setProperties({
        deleted_at: new Date(),
        deleted_by: deletedBy,
        can_delete: false,
        can_permanently_delete:
          this.siteSettings.can_permanently_delete && deletedBy.admin,
        can_recover: true,
      });
    } else {
      const key =
        this.post_number === 1
          ? "topic.deleted_by_author_simple"
          : "post.deleted_by_author_simple";
      promise = cook(i18n(key)).then((cooked) => {
        this.setProperties({
          cooked,
          can_delete: false,
          can_permanently_delete: false,
          version: this.version + 1,
          can_recover: true,
          can_edit: false,
          user_deleted: true,
        });
      });
    }

    return promise || Promise.resolve();
  }

  /**
   Changes the state of the post to NOT be deleted. Does not call the server.
   This can only be called after setDeletedState was called, but the delete
   failed on the server.
   **/
  undoDeleteState() {
    if (this.oldCooked) {
      this.setProperties({
        deleted_at: null,
        deleted_by: null,
        cooked: this.oldCooked,
        version: this.version - 1,
        can_recover: false,
        can_delete: true,
        user_deleted: false,
      });
    }
  }

  destroy(deletedBy, opts) {
    return this.setDeletedState(deletedBy).then(() => {
      return ajax("/posts/" + this.id, {
        data: { context: window.location.pathname, ...opts },
        type: "DELETE",
      });
    });
  }

  /**
   * Updates a post from another's attributes. This will normally happen when a post is loading but
   * is already found in an identity map.
   **/
  updateFromPost(otherPost) {
    [
      ...Object.keys(otherPost),
      ...trackedPropertiesForPostUpdate,
      ...pluginTrackedProperties,
    ].forEach((key) => {
      let value = otherPost[key],
        oldValue = this[key];

      if (!value) {
        value = null;
      }
      if (!oldValue) {
        oldValue = null;
      }

      let skip = false;
      if (typeof value !== "function" && oldValue !== value) {
        // wishing for an identity map
        if (key === "reply_to_user" && value && oldValue) {
          skip =
            value.username === oldValue.username ||
            get(value, "username") === get(oldValue, "username");
        }

        if (!skip) {
          this.set(key, value);
        }
      }
    });
  }

  expandHidden() {
    return ajax(`/posts/${this.id}/cooked.json`).then((result) => {
      this.setProperties({ cooked: result.cooked, cooked_hidden: false });
    });
  }

  rebake() {
    return ajax(`/posts/${this.id}/rebake`, { type: "PUT" }).catch(
      popupAjaxError
    );
  }

  unhide() {
    return ajax(`/posts/${this.id}/unhide`, { type: "PUT" });
  }

  createBookmark(data) {
    this.setProperties({
      "topic.bookmarked": true,
      bookmarked: true,
      bookmark_reminder_at: data.reminder_at,
      bookmark_auto_delete_preference: data.auto_delete_preference,
      bookmark_name: data.name,
      bookmark_id: data.id,
    });
    this.topic.incrementProperty("bookmarksWereChanged");
    this.appEvents.trigger("bookmarks:changed", data, {
      target: "post",
      targetId: this.id,
    });
    this.appEvents.trigger("post-stream:refresh", { id: this.id });
  }

  deleteBookmark(bookmarked) {
    this.set("topic.bookmarked", bookmarked);
    this.clearBookmark();
  }

  clearBookmark() {
    this.setProperties({
      bookmark_reminder_at: null,
      bookmark_name: null,
      bookmark_id: null,
      bookmarked: false,
      bookmark_auto_delete_preference: null,
    });
    this.topic.incrementProperty("bookmarksWereChanged");
    this.appEvents.trigger("bookmarks:changed", null, {
      target: "post",
      targetId: this.id,
    });
  }

  updateActionsSummary(json) {
    if (json && json.id === this.id) {
      json = Post.munge(json);
      this.set("actions_summary", json.actions_summary);
    }
  }

  updateLikeCount(count, userId, eventType) {
    let ownAction = this.currentUser?.id === userId;
    let ownLike = ownAction && eventType === "liked";
    let current_actions_summary = this.get("actions_summary");
    let likeActionID = Site.current().post_action_types.find(
      (a) => a.name_key === "like"
    ).id;
    const newActionObject = { id: likeActionID, count, acted: ownLike };

    if (!this.actions_summary.find((entry) => entry.id === likeActionID)) {
      let json = Post.munge({
        id: this.id,
        actions_summary: [newActionObject],
      });
      this.set(
        "actions_summary",
        Object.assign(current_actions_summary, json.actions_summary)
      );
      this.set("actionByName", json.actionByName);
      this.set("likeAction", json.likeAction);
    } else {
      newActionObject.acted =
        (ownLike || this.likeAction.acted) &&
        !(eventType === "unliked" && ownAction);

      Object.assign(
        this.actions_summary.find((entry) => entry.id === likeActionID),
        newActionObject
      );
      Object.assign(this.actionByName["like"], newActionObject);
      Object.assign(this.likeAction, newActionObject);
    }
  }

  revertToRevision(version) {
    return ajax(`/posts/${this.id}/revisions/${version}/revert`, {
      type: "PUT",
    });
  }

  get topicNotificationLevel() {
    return this.topic.details.notification_level;
  }

  get userBadges() {
    if (!this.topic?.user_badges) {
      return;
    }
    const badgeIds = this.topic.user_badges.users[this.user_id]?.badge_ids;
    if (badgeIds) {
      return badgeIds.map((badgeId) => this.topic.user_badges.badges[badgeId]);
    }
  }
}
