import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ActionSummary from "discourse/models/action-summary";
import { propertyEqual } from "discourse/lib/computed";
import Quote from "discourse/lib/quote";
import computed from "ember-addons/ember-computed-decorators";
import { postUrl } from "discourse/lib/utilities";
import { cookAsync } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import Composer from "discourse/models/composer";

const Post = RestModel.extend({
  @computed()
  siteSettings() {
    // TODO: Remove this once one instantiate all `Discourse.Post` models via the store.
    return Discourse.SiteSettings;
  },

  @computed("url")
  shareUrl(url) {
    const user = Discourse.User.current();
    const userSuffix = user ? "?u=" + user.get("username_lower") : "";

    if (this.get("firstPost")) {
      return this.get("topic.url") + userSuffix;
    } else {
      return url + userSuffix;
    }
  },

  new_user: Ember.computed.equal("trust_level", 0),
  firstPost: Ember.computed.equal("post_number", 1),

  // Posts can show up as deleted if the topic is deleted
  deletedViaTopic: Ember.computed.and("firstPost", "topic.deleted_at"),
  deleted: Ember.computed.or("deleted_at", "deletedViaTopic"),
  notDeleted: Ember.computed.not("deleted"),

  @computed("name", "username")
  showName(name, username) {
    return (
      name && name !== username && Discourse.SiteSettings.display_name_on_posts
    );
  },

  @computed("firstPost", "deleted_by", "topic.deleted_by")
  postDeletedBy(firstPost, deletedBy, topicDeletedBy) {
    return firstPost ? topicDeletedBy : deletedBy;
  },

  @computed("firstPost", "deleted_at", "topic.deleted_at")
  postDeletedAt(firstPost, deletedAt, topicDeletedAt) {
    return firstPost ? topicDeletedAt : deletedAt;
  },

  @computed("post_number", "topic_id", "topic.slug")
  url(postNr, topicId, slug) {
    return postUrl(
      slug || this.get("topic_slug"),
      topicId || this.get("topic.id"),
      postNr
    );
  },

  // Don't drop the /1
  @computed("post_number", "url")
  urlWithNumber(postNumber, baseUrl) {
    return postNumber === 1 ? baseUrl + "/1" : baseUrl;
  },

  @computed("username")
  usernameUrl(username) {
    return userPath(username);
  },

  topicOwner: propertyEqual("topic.details.created_by.id", "user_id"),

  updatePostField(field, value) {
    const data = {};
    data[field] = value;

    return ajax(`/posts/${this.get("id")}/${field}`, { type: "PUT", data })
      .then(() => {
        this.set(field, value);
      })
      .catch(popupAjaxError);
  },

  @computed("link_counts.@each.internal")
  internalLinks() {
    if (Ember.isEmpty(this.get("link_counts"))) return null;

    return this.get("link_counts")
      .filterBy("internal")
      .filterBy("title");
  },

  @computed("actions_summary.@each.can_act")
  flagsAvailable() {
    // TODO: Investigate why `this.site` is sometimes null when running
    // Search - Search with context
    if (!this.site) {
      return [];
    }

    return this.site.get("flagTypes").filter(item => {
      return this.get(`actionByName.${item.get("name_key")}.can_act`);
    });
  },

  afterUpdate(res) {
    if (res.category) {
      this.site.updateCategory(res.category);
    }
  },

  updateProperties() {
    return {
      post: { raw: this.get("raw"), edit_reason: this.get("editReason") },
      image_sizes: this.get("imageSizes")
    };
  },

  createProperties() {
    // composer only used once, defer the dependency
    const data = this.getProperties(Composer.serializedFieldsForCreate());
    data.reply_to_post_number = this.get("reply_to_post_number");
    data.image_sizes = this.get("imageSizes");

    const metaData = this.get("metaData");

    // Put the metaData into the request
    if (metaData) {
      data.meta_data = {};
      Object.keys(metaData).forEach(function(key) {
        data.meta_data[key] = metaData.get(key);
      });
    }

    return data;
  },

  // Expands the first post's content, if embedded and shortened.
  expand() {
    return ajax(`/posts/${this.get("id")}/expand-embed`).then(post => {
      this.set(
        "cooked",
        `<section class="expanded-embed">${post.cooked}</section>`
      );
    });
  },

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
      can_delete: false
    });

    return ajax(`/posts/${this.get("id")}/recover`, {
      type: "PUT",
      cache: false
    })
      .then(data => {
        this.setProperties({
          cooked: data.cooked,
          raw: data.raw,
          user_deleted: false,
          can_delete: true,
          version: data.version
        });
      })
      .catch(error => {
        popupAjaxError(error);
        this.setProperties(initProperties);
      });
  },

  /**
    Changes the state of the post to be deleted. Does not call the server, that should be
    done elsewhere.
  **/
  setDeletedState(deletedBy) {
    let promise;
    this.set("oldCooked", this.get("cooked"));

    // Moderators can delete posts. Users can only trigger a deleted at message, unless delete_removed_posts_after is 0.
    if (
      deletedBy.get("staff") ||
      Discourse.SiteSettings.delete_removed_posts_after === 0
    ) {
      this.setProperties({
        deleted_at: new Date(),
        deleted_by: deletedBy,
        can_delete: false,
        can_recover: true
      });
    } else {
      const key =
        this.get("post_number") === 1
          ? "topic.deleted_by_author"
          : "post.deleted_by_author";
      promise = cookAsync(
        I18n.t(key, {
          count: Discourse.SiteSettings.delete_removed_posts_after
        })
      ).then(cooked => {
        this.setProperties({
          cooked: cooked,
          can_delete: false,
          version: this.get("version") + 1,
          can_recover: true,
          can_edit: false,
          user_deleted: true
        });
      });
    }

    return promise || Ember.RSVP.Promise.resolve();
  },

  /**
    Changes the state of the post to NOT be deleted. Does not call the server.
    This can only be called after setDeletedState was called, but the delete
    failed on the server.
  **/
  undoDeleteState() {
    if (this.get("oldCooked")) {
      this.setProperties({
        deleted_at: null,
        deleted_by: null,
        cooked: this.get("oldCooked"),
        version: this.get("version") - 1,
        can_recover: false,
        can_delete: true,
        user_deleted: false
      });
    }
  },

  destroy(deletedBy) {
    return this.setDeletedState(deletedBy).then(() => {
      return ajax("/posts/" + this.get("id"), {
        data: { context: window.location.pathname },
        type: "DELETE"
      });
    });
  },

  /**
    Updates a post from another's attributes. This will normally happen when a post is loading but
    is already found in an identity map.
  **/
  updateFromPost(otherPost) {
    const self = this;
    Object.keys(otherPost).forEach(function(key) {
      let value = otherPost[key],
        oldValue = self[key];

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
            Ember.get(value, "username") === Ember.get(oldValue, "username");
        }

        if (!skip) {
          self.set(key, value);
        }
      }
    });
  },

  expandHidden() {
    return ajax("/posts/" + this.get("id") + "/cooked.json").then(result => {
      this.setProperties({ cooked: result.cooked, cooked_hidden: false });
    });
  },

  rebake() {
    return ajax("/posts/" + this.get("id") + "/rebake", { type: "PUT" });
  },

  unhide() {
    return ajax("/posts/" + this.get("id") + "/unhide", { type: "PUT" });
  },

  toggleBookmark() {
    const self = this;
    let bookmarkedTopic;

    this.toggleProperty("bookmarked");

    if (this.get("bookmarked") && !this.get("topic.bookmarked")) {
      this.set("topic.bookmarked", true);
      bookmarkedTopic = true;
    }

    // need to wait to hear back from server (stuff may not be loaded)

    return Discourse.Post.updateBookmark(this.get("id"), this.get("bookmarked"))
      .then(function(result) {
        self.set("topic.bookmarked", result.topic_bookmarked);
      })
      .catch(function(error) {
        self.toggleProperty("bookmarked");
        if (bookmarkedTopic) {
          self.set("topic.bookmarked", false);
        }
        throw new Error(error);
      });
  },

  updateActionsSummary(json) {
    if (json && json.id === this.get("id")) {
      json = Post.munge(json);
      this.set("actions_summary", json.actions_summary);
    }
  },

  revertToRevision(version) {
    return ajax(`/posts/${this.get("id")}/revisions/${version}/revert`, {
      type: "PUT"
    });
  }
});

Post.reopenClass({
  munge(json) {
    if (json.actions_summary) {
      const lookup = Ember.Object.create();

      // this area should be optimized, it is creating way too many objects per post
      json.actions_summary = json.actions_summary.map(function(a) {
        a.actionType = Discourse.Site.current().postActionTypeById(a.id);
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
      json.reply_to_user = Discourse.User.create(json.reply_to_user);
    }
    return json;
  },

  updateBookmark(postId, bookmarked) {
    return ajax("/posts/" + postId + "/bookmark", {
      type: "PUT",
      data: { bookmarked: bookmarked }
    });
  },

  deleteMany(post_ids, { agreeWithFirstReplyFlag = true } = {}) {
    return ajax("/posts/destroy_many", {
      type: "DELETE",
      data: { post_ids, agree_with_first_reply_flag: agreeWithFirstReplyFlag }
    });
  },

  mergePosts(post_ids) {
    return ajax("/posts/merge_posts", {
      type: "PUT",
      data: { post_ids }
    });
  },

  loadRevision(postId, version) {
    return ajax("/posts/" + postId + "/revisions/" + version + ".json").then(
      result => Ember.Object.create(result)
    );
  },

  hideRevision(postId, version) {
    return ajax("/posts/" + postId + "/revisions/" + version + "/hide", {
      type: "PUT"
    });
  },

  showRevision(postId, version) {
    return ajax("/posts/" + postId + "/revisions/" + version + "/show", {
      type: "PUT"
    });
  },

  loadQuote(postId) {
    return ajax("/posts/" + postId + ".json").then(result => {
      const post = Discourse.Post.create(result);
      return Quote.build(post, post.get("raw"), { raw: true, full: true });
    });
  },

  loadRawEmail(postId) {
    return ajax(`/posts/${postId}/raw-email.json`);
  }
});

export default Post;
