import { get } from "@ember/object";
import { not, notEmpty, equal, and, or } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { flushMap } from "discourse/models/store";
import RestModel from "discourse/models/rest";
import { propertyEqual, fmt } from "discourse/lib/computed";
import { longDate } from "discourse/lib/formatter";
import { isRTL } from "discourse/lib/text-direction";
import ActionSummary from "discourse/models/action-summary";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { censor } from "pretty-text/censored-words";
import { emojiUnescape } from "discourse/lib/text";
import PreloadStore from "preload-store";
import { userPath } from "discourse/lib/url";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import Session from "discourse/models/session";
import { Promise } from "rsvp";
import Site from "discourse/models/site";
import User from "discourse/models/user";

export function loadTopicView(topic, args) {
  const data = _.merge({}, args);
  const url = `${Discourse.getURL("/t/")}${topic.id}`;
  const jsonUrl = (data.nearPost ? `${url}/${data.nearPost}` : url) + ".json";

  delete data.nearPost;
  delete data.__type;
  delete data.store;

  return PreloadStore.getAndRemove(`topic_${topic.id}`, () =>
    ajax(jsonUrl, { data })
  ).then(json => {
    topic.updateFromJson(json);
    return json;
  });
}

export const ID_CONSTRAINT = /^\d+$/;

const Topic = RestModel.extend({
  message: null,
  errorLoading: false,

  @discourseComputed("last_read_post_number", "highest_post_number")
  visited(lastReadPostNumber, highestPostNumber) {
    // >= to handle case where there are deleted posts at the end of the topic
    return lastReadPostNumber >= highestPostNumber;
  },

  @discourseComputed("posters.firstObject")
  creator(poster) {
    return poster && poster.user;
  },

  @discourseComputed("posters.[]")
  lastPoster(posters) {
    let user;
    if (posters && posters.length > 0) {
      const latest = posters.filter(
        p => p.extras && p.extras.indexOf("latest") >= 0
      )[0];
      user = latest && latest.user;
    }
    return user || this.creator;
  },

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

      const poster_ids = posters.map(p => p.user && p.user.id).filter(id => id);
      participants.some(p => {
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
        moreCount: `+${allowedUserCount - maxUserCount + 1}`
      });
    }

    return users;
  },

  @discourseComputed("fancy_title")
  fancyTitle(title) {
    let fancyTitle = censor(
      emojiUnescape(title) || "",
      Site.currentProp("censored_regexp")
    );

    if (Discourse.SiteSettings.support_mixed_text_direction) {
      const titleDir = isRTL(title) ? "rtl" : "ltr";
      return `<span dir="${titleDir}">${fancyTitle}</span>`;
    }
    return fancyTitle;
  },

  // returns createdAt if there's no bumped date
  @discourseComputed("bumped_at", "createdAt")
  bumpedAt(bumped_at, createdAt) {
    if (bumped_at) {
      return new Date(bumped_at);
    } else {
      return createdAt;
    }
  },

  @discourseComputed("bumpedAt", "createdAt")
  bumpedAtTitle(bumpedAt, createdAt) {
    const firstPost = I18n.t("first_post");
    const lastPost = I18n.t("last_post");
    const createdAtDate = longDate(createdAt);
    const bumpedAtDate = longDate(bumpedAt);

    return `${firstPost}: ${createdAtDate}\n${lastPost}: ${bumpedAtDate}`;
  },

  @discourseComputed("created_at")
  createdAt(created_at) {
    return new Date(created_at);
  },

  @discourseComputed
  postStream() {
    return this.store.createRecord("postStream", {
      id: this.id,
      topic: this
    });
  },

  @discourseComputed("tags")
  visibleListTags(tags) {
    if (!tags || !Discourse.SiteSettings.suppress_overlapping_tags_in_list) {
      return tags;
    }

    const title = this.title;
    const newTags = [];

    tags.forEach(function(tag) {
      if (title.toLowerCase().indexOf(tag) === -1) {
        newTags.push(tag);
      }
    });

    return newTags;
  },

  @discourseComputed("related_messages")
  relatedMessages(relatedMessages) {
    if (relatedMessages) {
      const store = this.store;

      return this.set(
        "related_messages",
        relatedMessages.map(st => store.createRecord("topic", st))
      );
    }
  },

  @discourseComputed("suggested_topics")
  suggestedTopics(suggestedTopics) {
    if (suggestedTopics) {
      const store = this.store;

      return this.set(
        "suggested_topics",
        suggestedTopics.map(st => store.createRecord("topic", st))
      );
    }
  },

  @discourseComputed("posts_count")
  replyCount(postsCount) {
    return postsCount - 1;
  },

  @discourseComputed
  details() {
    return this.store.createRecord("topicDetails", {
      id: this.id,
      topic: this
    });
  },

  invisible: not("visible"),
  deleted: notEmpty("deleted_at"),

  @discourseComputed("id")
  searchContext(id) {
    return { type: "topic", id };
  },

  @on("init")
  @observes("category_id")
  _categoryIdChanged() {
    this.set("category", Category.findById(this.category_id));
  },

  @observes("categoryName")
  _categoryNameChanged() {
    const categoryName = this.categoryName;
    let category;
    if (categoryName) {
      category = this.site.get("categories").findBy("name", categoryName);
    }
    this.set("category", category);
  },

  categoryClass: fmt("category.fullSlug", "category-%@"),

  @discourseComputed("tags")
  tagClasses(tags) {
    return tags && tags.map(t => `tag-${t}`).join(" ");
  },

  @discourseComputed("url")
  shareUrl(url) {
    const user = User.current();
    const userQueryString = user ? `?u=${user.get("username_lower")}` : "";
    return `${url}${userQueryString}`;
  },

  printUrl: fmt("url", "%@/print"),

  @discourseComputed("id", "slug")
  url(id, slug) {
    slug = slug || "";
    if (slug.trim().length === 0) {
      slug = "topic";
    }
    return `${Discourse.getURL("/t/")}${slug}/${id}`;
  },

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = this.url;
    if (postNumber && postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
  },

  @discourseComputed("new_posts", "unread")
  totalUnread(newPosts, unread) {
    const count = (unread || 0) + (newPosts || 0);
    return count > 0 ? count : null;
  },

  @discourseComputed("last_read_post_number", "url")
  lastReadUrl(lastReadPostNumber) {
    return this.urlForPostNumber(lastReadPostNumber);
  },

  @discourseComputed("last_read_post_number", "highest_post_number", "url")
  lastUnreadUrl(lastReadPostNumber, highestPostNumber) {
    if (highestPostNumber <= lastReadPostNumber) {
      if (this.get("category.navigate_to_first_post_after_read")) {
        return this.urlForPostNumber(1);
      } else {
        return this.urlForPostNumber(lastReadPostNumber + 1);
      }
    } else {
      return this.urlForPostNumber(lastReadPostNumber + 1);
    }
  },

  @discourseComputed("highest_post_number", "url")
  lastPostUrl(highestPostNumber) {
    return this.urlForPostNumber(highestPostNumber);
  },

  @discourseComputed("url")
  firstPostUrl() {
    return this.urlForPostNumber(1);
  },

  @discourseComputed("url")
  summaryUrl() {
    const summaryQueryString = this.has_summary ? "?filter=summary" : "";
    return `${this.urlForPostNumber(1)}${summaryQueryString}`;
  },

  @discourseComputed("last_poster.username")
  lastPosterUrl(username) {
    return userPath(username);
  },

  // The amount of new posts to display. It might be different than what the server
  // tells us if we are still asynchronously flushing our "recently read" data.
  // So take what the browser has seen into consideration.
  @discourseComputed("new_posts", "id")
  displayNewPosts(newPosts, id) {
    const highestSeen = Session.currentProp("highestSeenByTopic")[id];
    if (highestSeen) {
      const delta = highestSeen - this.last_read_post_number;
      if (delta > 0) {
        let result = newPosts - delta;
        if (result < 0) {
          result = 0;
        }
        return result;
      }
    }
    return newPosts;
  },

  @discourseComputed("views")
  viewsHeat(v) {
    if (v >= Discourse.SiteSettings.topic_views_heat_high) {
      return "heatmap-high";
    }
    if (v >= Discourse.SiteSettings.topic_views_heat_medium) {
      return "heatmap-med";
    }
    if (v >= Discourse.SiteSettings.topic_views_heat_low) {
      return "heatmap-low";
    }
    return null;
  },

  @discourseComputed("archetype")
  archetypeObject(archetype) {
    return Site.currentProp("archetypes").findBy("id", archetype);
  },

  isPrivateMessage: equal("archetype", "private_message"),
  isBanner: equal("archetype", "banner"),

  toggleStatus(property) {
    this.toggleProperty(property);
    return this.saveStatus(property, !!this.get(property));
  },

  saveStatus(property, value, until) {
    if (property === "closed") {
      this.incrementProperty("posts_count");
    }
    return ajax(`${this.url}/status`, {
      type: "PUT",
      data: {
        status: property,
        enabled: !!value,
        until
      }
    });
  },

  makeBanner() {
    return ajax(`/t/${this.id}/make-banner`, { type: "PUT" }).then(() =>
      this.set("archetype", "banner")
    );
  },

  removeBanner() {
    return ajax(`/t/${this.id}/remove-banner`, {
      type: "PUT"
    }).then(() => this.set("archetype", "regular"));
  },

  toggleBookmark() {
    if (this.bookmarking) {
      return Promise.resolve();
    }
    this.set("bookmarking", true);

    const stream = this.postStream;
    const posts = get(stream, "posts");
    const firstPost =
      posts && posts[0] && posts[0].get("post_number") === 1 && posts[0];
    const bookmark = !this.bookmarked;
    const path = bookmark ? "/bookmark" : "/remove_bookmarks";

    const toggleBookmarkOnServer = () => {
      return ajax(`/t/${this.id}${path}`, { type: "PUT" })
        .then(() => {
          this.toggleProperty("bookmarked");
          if (bookmark && firstPost) {
            firstPost.set("bookmarked", true);
            return [firstPost.id];
          }
          if (!bookmark && posts) {
            const updated = [];
            posts.forEach(post => {
              if (post.get("bookmarked")) {
                post.set("bookmarked", false);
                updated.push(post.get("id"));
              }
            });
            return updated;
          }

          return [];
        })
        .catch(popupAjaxError)
        .finally(() => this.set("bookmarking", false));
    };

    const unbookmarkedPosts = [];
    if (!bookmark && posts) {
      posts.forEach(
        post => post.get("bookmarked") && unbookmarkedPosts.push(post)
      );
    }

    return new Promise(resolve => {
      if (unbookmarkedPosts.length > 1) {
        bootbox.confirm(
          I18n.t("bookmarks.confirm_clear"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          confirmed =>
            confirmed ? toggleBookmarkOnServer().then(resolve) : resolve()
        );
      } else {
        toggleBookmarkOnServer().then(resolve);
      }
    });
  },

  createGroupInvite(group) {
    return ajax(`/t/${this.id}/invite-group`, {
      type: "POST",
      data: { group }
    });
  },

  createInvite(user, group_names, custom_message) {
    return ajax(`/t/${this.id}/invite`, {
      type: "POST",
      data: { user, group_names, custom_message }
    });
  },

  generateInviteLink(email, groupNames, topicId) {
    return ajax("/invites/link", {
      type: "POST",
      data: { email, group_names: groupNames, topic_id: topicId }
    });
  },

  // Delete this topic
  destroy(deleted_by) {
    return ajax(`/t/${this.id}`, {
      data: { context: window.location.pathname },
      type: "DELETE"
    })
      .then(() => {
        this.setProperties({
          deleted_at: new Date(),
          deleted_by: deleted_by,
          "details.can_delete": false,
          "details.can_recover": true
        });
      })
      .catch(popupAjaxError);
  },

  // Recover this topic if deleted
  recover() {
    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      "details.can_delete": true,
      "details.can_recover": false
    });
    return ajax(`/t/${this.id}/recover`, {
      data: { context: window.location.pathname },
      type: "PUT"
    });
  },

  // Update our attributes from a JSON result
  updateFromJson(json) {
    const keys = Object.keys(json);
    if (!json.view_hidden) {
      this.details.updateFromJson(json.details);

      keys.removeObjects(["details", "post_stream"]);
    }
    keys.forEach(key => this.set(key, json[key]));
  },

  reload() {
    return ajax(`/t/${this.id}`, { type: "GET" }).then(topic_json =>
      this.updateFromJson(topic_json)
    );
  },

  isPinnedUncategorized: and("pinned", "category.isUncategorizedCategory"),

  clearPin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: false, unpinned: true });

    ajax(`/t/${this.id}/clear-pin`, {
      type: "PUT"
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  },

  togglePinnedForUser() {
    if (this.pinned) {
      this.clearPin();
    } else {
      this.rePin();
    }
  },

  rePin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: true, unpinned: false });

    ajax(`/t/${this.id}/re-pin`, {
      type: "PUT"
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  },

  @discourseComputed("excerpt")
  escapedExcerpt(excerpt) {
    return emojiUnescape(excerpt);
  },

  hasExcerpt: notEmpty("excerpt"),

  @discourseComputed("excerpt")
  excerptTruncated(excerpt) {
    return excerpt && excerpt.substr(excerpt.length - 8, 8) === "&hellip;";
  },

  readLastPost: propertyEqual("last_read_post_number", "highest_post_number"),
  canClearPin: and("pinned", "readLastPost"),
  canEditTags: or("details.can_edit", "details.can_edit_tags"),

  archiveMessage() {
    this.set("archiving", true);
    const promise = ajax(`/t/${this.id}/archive-message`, {
      type: "PUT"
    });

    promise
      .then(msg => {
        this.set("message_archived", true);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  },

  moveToInbox() {
    this.set("archiving", true);
    const promise = ajax(`/t/${this.id}/move-to-inbox`, { type: "PUT" });

    promise
      .then(msg => {
        this.set("message_archived", false);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  },

  publish() {
    return ajax(`/t/${this.id}/publish`, {
      type: "PUT",
      data: this.getProperties("destination_category_id")
    })
      .then(() => this.set("destination_category_id", null))
      .catch(popupAjaxError);
  },

  updateDestinationCategory(categoryId) {
    this.set("destination_category_id", categoryId);
    return ajax(`/t/${this.id}/shared-draft`, {
      method: "PUT",
      data: { category_id: categoryId }
    });
  },

  convertTopic(type, opts) {
    let args = { type: "PUT" };
    if (opts && opts.categoryId) {
      args.data = { category_id: opts.categoryId };
    }
    return ajax(`/t/${this.id}/convert-topic/${type}`, args);
  },

  resetBumpDate() {
    return ajax(`/t/${this.id}/reset-bump-date`, { type: "PUT" }).catch(
      popupAjaxError
    );
  },

  updateTags(tags) {
    if (!tags || tags.length === 0) {
      tags = [""];
    }

    return ajax(`/t/${this.id}/tags`, {
      type: "PUT",
      data: { tags: tags }
    });
  }
});

Topic.reopenClass({
  NotificationLevel: {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTED: 0
  },

  createActionSummary(result) {
    if (result.actions_summary) {
      const lookup = EmberObject.create();
      result.actions_summary = result.actions_summary.map(a => {
        a.post = result;
        a.actionType = Site.current().postActionTypeById(a.id);
        const actionSummary = ActionSummary.create(a);
        lookup.set(a.actionType.get("name_key"), actionSummary);
        return actionSummary;
      });
      result.set("actionByName", lookup);
    }
  },

  update(topic, props) {
    // We support `category_id` and `categoryId` for compatibility
    if (typeof props.categoryId !== "undefined") {
      props.category_id = props.categoryId;
      delete props.categoryId;
    }

    // Make sure we never change the category for private messages
    if (topic.get("isPrivateMessage")) {
      delete props.category_id;
    }

    return ajax(topic.get("url"), {
      type: "PUT",
      data: JSON.stringify(props),
      contentType: "application/json"
    }).then(result => {
      // The title can be cleaned up server side
      props.title = result.basic_topic.title;
      props.fancy_title = result.basic_topic.fancy_title;
      topic.setProperties(props);
    });
  },

  create() {
    const result = this._super.apply(this, arguments);
    this.createActionSummary(result);
    return result;
  },

  // Load a topic, but accepts a set of filters
  find(topicId, opts) {
    let url = Discourse.getURL("/t/") + topicId;
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
      opts.userFilters.forEach(function(username) {
        data.username_filters.push(username);
      });
    }

    // Add the summary of filter if we have it
    if (opts.summary === true) {
      data.summary = true;
    }

    // Check the preload store. If not, load it via JSON
    return ajax(`${url}.json`, { data });
  },

  changeOwners(topicId, opts) {
    const promise = ajax(`/t/${topicId}/change-owner`, {
      type: "POST",
      data: opts
    }).then(result => {
      if (result.success) return result;
      promise.reject(new Error("error changing ownership of posts"));
    });
    return promise;
  },

  changeTimestamp(topicId, timestamp) {
    const promise = ajax(`/t/${topicId}/change-timestamp`, {
      type: "PUT",
      data: { timestamp }
    }).then(result => {
      if (result.success) return result;
      promise.reject(new Error("error updating timestamp of topic"));
    });
    return promise;
  },

  bulkOperation(topics, operation) {
    return ajax("/topics/bulk", {
      type: "PUT",
      data: {
        topic_ids: topics.map(t => t.get("id")),
        operation
      }
    });
  },

  bulkOperationByFilter(filter, operation, categoryId, options) {
    let data = { filter, operation };

    if (options && options.includeSubcategories) {
      data.include_subcategories = true;
    }

    if (categoryId) data.category_id = categoryId;
    return ajax("/topics/bulk", {
      type: "PUT",
      data
    });
  },

  resetNew(category, include_subcategories) {
    const data = category
      ? { category_id: category.id, include_subcategories }
      : {};
    return ajax("/topics/reset-new", { type: "PUT", data });
  },

  idForSlug(slug) {
    return ajax(`/t/id_for/${slug}`);
  }
});

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

export default Topic;
