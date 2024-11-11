import { cached } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias, and, equal, notEmpty, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { resolveShareUrl } from "discourse/helpers/share-url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fmt, propertyEqual } from "discourse/lib/computed";
import { TOPIC_VISIBILITY_REASONS } from "discourse/lib/constants";
import { longDate } from "discourse/lib/formatter";
import { applyModelTransformations } from "discourse/lib/model-transformers";
import PreloadStore from "discourse/lib/preload-store";
import { emojiUnescape } from "discourse/lib/text";
import { fancyTitle } from "discourse/lib/topic-fancy-title";
import DiscourseURL, { userPath } from "discourse/lib/url";
import ActionSummary from "discourse/models/action-summary";
import Bookmark from "discourse/models/bookmark";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import { flushMap } from "discourse/services/store";
import deprecated from "discourse-common/lib/deprecated";
import getURL from "discourse-common/lib/get-url";
import { deepMerge } from "discourse-common/lib/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import Category from "./category";

export function loadTopicView(topic, args) {
  const data = deepMerge({}, args);
  const url = `/t/${topic.id}`;
  const jsonUrl = (data.nearPost ? `${url}/${data.nearPost}` : url) + ".json";

  delete data.nearPost;
  delete data.__type;
  delete data.store;

  return PreloadStore.getAndRemove(`topic_${topic.id}`, () =>
    ajax(jsonUrl, { data })
  ).then(async (json) => {
    json.categories?.forEach((c) => topic.site.updateCategory(c));
    topic.updateFromJson(json);
    await Topic.applyTransformations([topic]);
    return json;
  });
}

export const ID_CONSTRAINT = /^\d+$/;
let _customLastUnreadUrlCallbacks = [];

export default class Topic extends RestModel {
  static NotificationLevel = {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTED: 0,
  };

  static munge(json) {
    // ensure we are not overriding category computed property
    delete json.category;
    json.bookmarks = json.bookmarks || [];
    return json;
  }

  static createActionSummary(result) {
    if (result.actions_summary) {
      const lookup = EmberObject.create();
      result.actions_summary = result.actions_summary.map((a) => {
        a.post = result;
        a.actionType = Site.current().postActionTypeById(a.id);
        const actionSummary = ActionSummary.create(a);
        lookup.set(a.actionType.get("name_key"), actionSummary);
        return actionSummary;
      });
      result.set("actionByName", lookup);
    }
  }

  static update(topic, props, opts = {}) {
    // We support `category_id` and `categoryId` for compatibility
    if (typeof props.categoryId !== "undefined") {
      props.category_id = props.categoryId;
      delete props.categoryId;
    }

    // Make sure we never change the category for private messages
    if (topic.get("isPrivateMessage")) {
      delete props.category_id;
    }

    const data = { ...props };
    if (opts.fastEdit) {
      data.keep_existing_draft = true;
    }
    return ajax(topic.get("url"), {
      type: "PUT",
      data: JSON.stringify(data),
      contentType: "application/json",
    }).then((result) => {
      // The title can be cleaned up server side
      props.title = result.basic_topic.title;
      props.fancy_title = result.basic_topic.fancy_title;
      if (topic.is_shared_draft) {
        props.destination_category_id = props.category_id;
        delete props.category_id;
      }
      topic.setProperties(props);
    });
  }

  static create() {
    const result = super.create.apply(this, arguments);
    this.createActionSummary(result);
    return result;
  }

  // Load a topic, but accepts a set of filters
  static find(topicId, opts) {
    let url = getURL("/t/") + topicId;
    if (opts.nearPost) {
      url += `/${opts.nearPost}`;
    }

    const data = {};
    if (opts.postsAfter) {
      data.posts_after = opts.postsAfter;
    }
    if (opts.postsBefore) {
      data.posts_before = opts.postsBefore;
    }
    if (opts.trackVisit) {
      data.track_visit = true;
    }

    // Add username filters if we have them
    if (opts.userFilters && opts.userFilters.length > 0) {
      data.username_filters = [];
      opts.userFilters.forEach(function (username) {
        data.username_filters.push(username);
      });
    }

    // Add the summary of filter if we have it
    if (opts.summary === true) {
      data.summary = true;
    }

    // Check the preload store. If not, load it via JSON
    return ajax(`${url}.json`, { data });
  }

  static changeOwners(topicId, opts) {
    const promise = ajax(`/t/${topicId}/change-owner`, {
      type: "POST",
      data: opts,
    }).then((result) => {
      if (result.success) {
        return result;
      }
      promise.reject(new Error("error changing ownership of posts"));
    });
    return promise;
  }

  static changeTimestamp(topicId, timestamp) {
    const promise = ajax(`/t/${topicId}/change-timestamp`, {
      type: "PUT",
      data: { timestamp },
    }).then((result) => {
      if (result.success) {
        return result;
      }
      promise.reject(new Error("error updating timestamp of topic"));
    });
    return promise;
  }

  static bulkOperation(topics, operation, options, tracked) {
    const data = {
      topic_ids: topics.mapBy("id"),
      operation,
      tracked,
    };

    if (options) {
      if (options.silent) {
        data.silent = true;
      }
    }

    return ajax("/topics/bulk", {
      type: "PUT",
      data,
    });
  }

  static bulkOperationByFilter(filter, operation, options, tracked) {
    const data = { filter, operation, tracked };

    if (options) {
      if (options.categoryId) {
        data.category_id = options.categoryId;
      }
      if (options.includeSubcategories) {
        data.include_subcategories = true;
      }
      if (options.tagName) {
        data.tag_name = options.tagName;
      }

      if (options.private_message_inbox) {
        data.private_message_inbox = options.private_message_inbox;

        if (options.group_name) {
          data.group_name = options.group_name;
        }
      }
    }

    return ajax("/topics/bulk", {
      type: "PUT",
      data,
    });
  }

  static resetNew(category, include_subcategories, opts = {}) {
    let { tracked, tag, topicIds } = {
      tracked: false,
      tag: null,
      topicIds: null,
      ...opts,
    };

    const data = { tracked };
    if (category) {
      data.category_id = category.id;
      data.include_subcategories = include_subcategories;
    }
    if (tag) {
      data.tag_id = tag.id;
    }
    if (topicIds) {
      data.topic_ids = topicIds;
    }

    if (opts.dismissPosts) {
      data.dismiss_posts = opts.dismissPosts;
    }

    if (opts.dismissTopics) {
      data.dismiss_topics = opts.dismissTopics;
    }

    if (opts.untrack) {
      data.untrack = opts.untrack;
    }

    return ajax("/topics/reset-new", { type: "PUT", data });
  }

  static pmResetNew(opts = {}) {
    const data = {};

    if (opts.topicIds) {
      data.topic_ids = opts.topicIds;
    }

    if (opts.inbox) {
      data.inbox = opts.inbox;

      if (opts.groupName) {
        data.group_name = opts.groupName;
      }
    }

    return ajax("/topics/pm-reset-new", { type: "PUT", data });
  }

  static idForSlug(slug) {
    return ajax(`/t/id_for/${slug}`);
  }

  static setSlowMode(topicId, seconds, enabledUntil) {
    const data = { seconds };
    data.enabled_until = enabledUntil;

    return ajax(`/t/${topicId}/slow_mode`, { type: "PUT", data });
  }

  static async applyTransformations(topics) {
    await applyModelTransformations("topic", topics);
  }

  @service currentUser;
  @service siteSettings;

  message = null;
  errorLoading = false;

  @alias("lastPoster.user") lastPosterUser;
  @alias("lastPoster.primary_group") lastPosterGroup;
  @alias("details.allowed_groups") allowedGroups;
  @notEmpty("deleted_at") deleted;
  @fmt("url", "%@/print") printUrl;
  @equal("archetype", "private_message") isPrivateMessage;
  @equal("archetype", "banner") isBanner;
  @alias("bookmarks.length") bookmarkCount;
  @and("pinned", "category.isUncategorizedCategory") isPinnedUncategorized;
  @notEmpty("excerpt") hasExcerpt;
  @propertyEqual("last_read_post_number", "highest_post_number") readLastPost;
  @and("pinned", "readLastPost") canClearPin;
  @or("details.can_edit", "details.can_edit_tags") canEditTags;

  @discourseComputed("last_read_post_number", "highest_post_number")
  visited(lastReadPostNumber, highestPostNumber) {
    // >= to handle case where there are deleted posts at the end of the topic
    return lastReadPostNumber >= highestPostNumber;
  }

  @discourseComputed("posters.firstObject")
  creator(poster) {
    return poster && poster.user;
  }

  @discourseComputed("posters.[]")
  lastPoster(posters) {
    if (posters && posters.length > 0) {
      const latest = posters.filter((p) => p.extras?.includes("latest"))[0];
      return latest || posters.firstObject;
    }
  }

  @discourseComputed("posters.[]", "participants.[]", "allowed_user_count")
  featuredUsers(posters, participants, allowedUserCount) {
    let users = posters;
    const maxUserCount = 5;
    const posterCount = users.length;

    if (this.isPrivateMessage && participants && posterCount < maxUserCount) {
      let pushOffset = 0;
      if (posterCount > 1) {
        const lastUser = users[posterCount - 1];
        if (lastUser.extras && lastUser.extras.includes("latest")) {
          pushOffset = 1;
        }
      }

      const poster_ids = posters
        .map((p) => p.user && p.user.id)
        .filter((id) => id);
      participants.some((p) => {
        if (!poster_ids.includes(p.user_id)) {
          users.splice(users.length - pushOffset, 0, p);
          if (users.length === maxUserCount) {
            return true;
          }
        }
        return false;
      });
    }

    if (this.isPrivateMessage && allowedUserCount > maxUserCount) {
      users.splice(maxUserCount - 2, 1); // remove second-last avatar
      users.push({
        moreCount: `+${allowedUserCount - maxUserCount + 1}`,
      });
    }

    return users;
  }

  @discourseComputed("fancy_title")
  fancyTitle(title) {
    return fancyTitle(title, this.siteSettings.support_mixed_text_direction);
  }

  // returns createdAt if there's no bumped date
  @discourseComputed("bumped_at", "createdAt")
  bumpedAt(bumped_at, createdAt) {
    if (bumped_at) {
      return new Date(bumped_at);
    } else {
      return createdAt;
    }
  }

  @discourseComputed("bumpedAt", "createdAt")
  bumpedAtTitle(bumpedAt, createdAt) {
    const BUMPED_FORMAT = "YYYY-MM-DDTHH:mm:ss";
    if (moment(bumpedAt).isValid() && moment(createdAt).isValid()) {
      const bumpedAtStr = moment(bumpedAt).format(BUMPED_FORMAT);
      const createdAtStr = moment(createdAt).format(BUMPED_FORMAT);

      return bumpedAtStr !== createdAtStr
        ? `${I18n.t("topic.created_at", {
            date: longDate(createdAt),
          })}\n${I18n.t("topic.bumped_at", { date: longDate(bumpedAt) })}`
        : I18n.t("topic.created_at", { date: longDate(createdAt) });
    }
  }

  @discourseComputed("created_at")
  createdAt(created_at) {
    return new Date(created_at);
  }

  @discourseComputed
  postStream() {
    return this.store.createRecord("postStream", {
      id: this.id,
      topic: this,
    });
  }

  @discourseComputed("tags")
  visibleListTags(tags) {
    if (!tags || !this.siteSettings.suppress_overlapping_tags_in_list) {
      return tags;
    }

    const title = this.title.toLowerCase();
    const newTags = [];

    tags.forEach(function (tag) {
      if (!title.includes(tag.toLowerCase())) {
        newTags.push(tag);
      }
    });

    return newTags;
  }

  @dependentKeyCompat
  @cached
  get relatedMessages() {
    return this.get("related_messages")?.map((st) =>
      this.store.createRecord("topic", st)
    );
  }

  @dependentKeyCompat
  @cached
  get suggestedTopics() {
    return this.get("suggested_topics")?.map((st) =>
      this.store.createRecord("topic", st)
    );
  }

  @discourseComputed("posts_count")
  replyCount(postsCount) {
    return postsCount - 1;
  }

  get details() {
    return (this._details ??= this.store.createRecord("topicDetails", {
      id: this.id,
      topic: this,
    }));
  }

  set details(value) {
    this._details = value;
  }

  @discourseComputed("visible")
  invisible(visible) {
    return visible !== undefined ? !visible : undefined;
  }

  @discourseComputed("visibility_reason_id")
  visibilityReasonTranslated() {
    if (
      this.visibility_reason_id &&
      this.visibility_reason_id !== TOPIC_VISIBILITY_REASONS.unknown
    ) {
      const reasonKey = Object.keys(TOPIC_VISIBILITY_REASONS).find(
        (key) => TOPIC_VISIBILITY_REASONS[key] === this.visibility_reason_id
      );
      return I18n.t(`topic_statuses.visibility_reasons.${reasonKey}`);
    }

    return "";
  }

  @discourseComputed("id")
  searchContext(id) {
    return { type: "topic", id };
  }

  @computed("category_id", "site.categoriesById.[]")
  get category() {
    return Category.findById(this.category_id);
  }

  set category(newCategory) {
    this.set("category_id", newCategory?.id);
  }

  @discourseComputed("url")
  shareUrl(url) {
    return resolveShareUrl(url, this.currentUser);
  }

  @discourseComputed("id", "slug")
  url(id, slug) {
    slug = slug || "";
    if (slug.trim().length === 0) {
      slug = "topic";
    }
    return `${getURL("/t/")}${slug}/${id}`;
  }

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = this.url;
    if (postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
  }

  @discourseComputed("unread_posts", "new_posts")
  totalUnread(unreadPosts, newPosts) {
    deprecated("The totalUnread property of the topic model is deprecated", {
      id: "discourse.topic.totalUnread",
    });
    return unreadPosts || newPosts;
  }

  @discourseComputed("unread_posts", "new_posts")
  displayNewPosts(unreadPosts, newPosts) {
    deprecated(
      "The displayNewPosts property of the topic model is deprecated",
      { id: "discourse.topic.totalUnread" }
    );
    return unreadPosts || newPosts;
  }

  @discourseComputed("last_read_post_number", "url")
  lastReadUrl(lastReadPostNumber) {
    return this.urlForPostNumber(lastReadPostNumber);
  }

  @discourseComputed("last_read_post_number", "highest_post_number", "url")
  lastUnreadUrl(lastReadPostNumber, highestPostNumber) {
    let customUrl = null;
    _customLastUnreadUrlCallbacks.some((cb) => {
      const result = cb(this);
      if (result) {
        customUrl = result;
        return true;
      }
    });

    if (customUrl) {
      return customUrl;
    }

    if (
      lastReadPostNumber >= highestPostNumber &&
      this.get("category.navigate_to_first_post_after_read")
    ) {
      return this.urlForPostNumber(1);
    }

    let postNumber = lastReadPostNumber + 1;
    if (postNumber > highestPostNumber) {
      postNumber = highestPostNumber;
    }

    return this.urlForPostNumber(postNumber);
  }

  @discourseComputed("highest_post_number", "url")
  lastPostUrl(highestPostNumber) {
    return this.urlForPostNumber(highestPostNumber);
  }

  @discourseComputed("url")
  firstPostUrl() {
    return this.urlForPostNumber(1);
  }

  @discourseComputed("url")
  summaryUrl() {
    const summaryQueryString = this.has_summary ? "?filter=summary" : "";
    return `${this.urlForPostNumber(1)}${summaryQueryString}`;
  }

  @discourseComputed("last_poster.username")
  lastPosterUrl(username) {
    return userPath(username);
  }

  @discourseComputed("views")
  viewsHeat(v) {
    if (v >= this.siteSettings.topic_views_heat_high) {
      return "heatmap-high";
    }
    if (v >= this.siteSettings.topic_views_heat_medium) {
      return "heatmap-med";
    }
    if (v >= this.siteSettings.topic_views_heat_low) {
      return "heatmap-low";
    }
    return null;
  }

  @discourseComputed("archetype")
  archetypeObject(archetype) {
    return Site.currentProp("archetypes").findBy("id", archetype);
  }

  toggleStatus(property) {
    this.toggleProperty(property);
    return this.saveStatus(property, !!this.get(property));
  }

  saveStatus(property, value, until) {
    if (property === "closed") {
      this.incrementProperty("posts_count");
    }
    return ajax(`${this.url}/status`, {
      type: "PUT",
      data: {
        status: property,
        enabled: !!value,
        until,
      },
    });
  }

  makeBanner() {
    return ajax(`/t/${this.id}/make-banner`, { type: "PUT" }).then(() =>
      this.set("archetype", "banner")
    );
  }

  removeBanner() {
    return ajax(`/t/${this.id}/remove-banner`, {
      type: "PUT",
    }).then(() => this.set("archetype", "regular"));
  }

  afterPostBookmarked(post) {
    post.set("bookmarked", true);
  }

  firstPost() {
    const postStream = this.postStream;
    let firstPost = postStream.get("posts.firstObject");

    if (firstPost && firstPost.post_number === 1) {
      return Promise.resolve(firstPost);
    }

    const postId = postStream.findPostIdForPostNumber(1);
    if (postId) {
      return this.postById(postId);
    } else {
      return this.postStream.loadPostByPostNumber(1);
    }
  }

  postById(id) {
    const loaded = this.postStream.findLoadedPost(id);
    if (loaded) {
      return Promise.resolve(loaded);
    }

    return this.postStream.loadPost(id);
  }

  deleteBookmarks() {
    return ajax(`/t/${this.id}/remove_bookmarks`, { type: "PUT" });
  }

  removeBookmark(id) {
    if (!this.bookmarks) {
      this.set("bookmarks", []);
    }
    this.set(
      "bookmarks",
      this.bookmarks.filter((bookmark) => {
        if (bookmark.id === id && bookmark.bookmarkable_type === "Topic") {
          this.appEvents.trigger(
            "bookmarks:changed",
            null,
            bookmark.attachedTo()
          );
        }

        return bookmark.id !== id;
      })
    );
    this.set("bookmarked", this.bookmarks.length);
    this.incrementProperty("bookmarksWereChanged");
  }

  clearBookmarks() {
    this.toggleProperty("bookmarked");

    const postIds = this.bookmarks
      .filterBy("bookmarkable_type", "Post")
      .mapBy("bookmarkable_id");
    postIds.forEach((postId) => {
      const loadedPost = this.postStream.findLoadedPost(postId);
      if (loadedPost) {
        loadedPost.clearBookmark();
      }
    });
    this.set("bookmarks", []);

    return postIds;
  }

  createGroupInvite(group) {
    return ajax(`/t/${this.id}/invite-group`, {
      type: "POST",
      data: { group },
    });
  }

  createInvite(user, group_ids, custom_message) {
    return ajax(`/t/${this.id}/invite`, {
      type: "POST",
      data: { user, group_ids, custom_message },
    });
  }

  generateInviteLink(email, group_ids, topic_id) {
    return ajax("/invites", {
      type: "POST",
      data: { email, skip_email: true, group_ids, topic_id },
    });
  }

  // Delete this topic
  destroy(deleted_by, opts = {}) {
    return ajax(`/t/${this.id}`, {
      data: { context: window.location.pathname, ...opts },
      type: "DELETE",
    })
      .then(() => {
        this.setProperties({
          deleted_at: new Date(),
          deleted_by,
          "details.can_delete": false,
          "details.can_recover": true,
          "details.can_permanently_delete":
            this.siteSettings.can_permanently_delete && deleted_by.admin,
        });
        if (
          opts.force_destroy ||
          (!deleted_by.staff &&
            !deleted_by.groups.some((group) =>
              this.category?.moderating_group_ids?.includes(group.id)
            ) &&
            !deleted_by.can_delete_all_posts_and_topics)
        ) {
          DiscourseURL.redirectTo("/");
        }
      })
      .catch(popupAjaxError);
  }

  // Recover this topic if deleted
  recover() {
    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      "details.can_delete": true,
      "details.can_recover": false,
    });
    return ajax(`/t/${this.id}/recover`, {
      data: { context: window.location.pathname },
      type: "PUT",
    });
  }

  // Update our attributes from a JSON result
  updateFromJson(json) {
    const keys = Object.keys(json);
    if (!json.view_hidden) {
      this.details.updateFromJson(json.details);

      keys.removeObjects(["details", "post_stream"]);

      if (json.published_page) {
        this.set(
          "publishedPage",
          this.store.createRecord("published-page", json.published_page)
        );
      }
    }
    keys.forEach((key) => this.set(key, json[key]));

    if (this.bookmarks.length) {
      this.set(
        "bookmarks",
        this.bookmarks.map((bm) => Bookmark.create(bm))
      );
    }

    return this;
  }

  reload() {
    return ajax(`/t/${this.id}`, { type: "GET" }).then((topic_json) =>
      this.updateFromJson(topic_json)
    );
  }

  clearPin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: false, unpinned: true });

    ajax(`/t/${this.id}/clear-pin`, {
      type: "PUT",
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  }

  togglePinnedForUser() {
    if (this.pinned) {
      this.clearPin();
    } else {
      this.rePin();
    }
  }

  rePin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: true, unpinned: false });

    ajax(`/t/${this.id}/re-pin`, {
      type: "PUT",
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  }

  @discourseComputed("excerpt")
  escapedExcerpt(excerpt) {
    return emojiUnescape(excerpt);
  }

  @discourseComputed("excerpt")
  excerptTruncated(excerpt) {
    return excerpt && excerpt.slice(-8) === "&hellip;";
  }

  archiveMessage() {
    this.set("archiving", true);
    const promise = ajax(`/t/${this.id}/archive-message`, {
      type: "PUT",
    });

    promise
      .then((msg) => {
        this.set("message_archived", true);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  }

  moveToInbox() {
    this.set("archiving", true);
    const promise = ajax(`/t/${this.id}/move-to-inbox`, { type: "PUT" });

    promise
      .then((msg) => {
        this.set("message_archived", false);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  }

  publish() {
    return ajax(`/t/${this.id}/publish`, {
      type: "PUT",
      data: this.getProperties("destination_category_id"),
    })
      .then(() => this.set("destination_category_id", null))
      .catch(popupAjaxError);
  }

  updateDestinationCategory(categoryId) {
    this.set("destination_category_id", categoryId);
    return ajax(`/t/${this.id}/shared-draft`, {
      type: "PUT",
      data: { category_id: categoryId },
    });
  }

  convertTopic(type, opts) {
    let args = { type: "PUT" };
    if (opts && opts.categoryId) {
      args.data = { category_id: opts.categoryId };
    }
    return ajax(`/t/${this.id}/convert-topic/${type}`, args);
  }

  resetBumpDate() {
    return ajax(`/t/${this.id}/reset-bump-date`, { type: "PUT" }).catch(
      popupAjaxError
    );
  }

  updateTags(tags) {
    if (!tags || tags.length === 0) {
      tags = [""];
    }

    return ajax(`/t/${this.id}/tags`, {
      type: "PUT",
      data: { tags },
    });
  }
}

function moveResult(result) {
  if (result.success) {
    // We should be hesitant to flush the map but moving ids is one rare case
    flushMap();
    return result;
  }
  throw new Error("error moving posts topic");
}

export function movePosts(topicId, data) {
  return ajax(`/t/${topicId}/move-posts`, { type: "POST", data }).then(
    moveResult
  );
}

export function mergeTopic(topicId, data) {
  return ajax(`/t/${topicId}/merge-topic`, { type: "POST", data }).then(
    moveResult
  );
}

export function registerCustomLastUnreadUrlCallback(fn) {
  _customLastUnreadUrlCallbacks.push(fn);
}

// Should only be used in tests
export function clearCustomLastUnreadUrlCallbacks() {
  _customLastUnreadUrlCallbacks.clear();
}
