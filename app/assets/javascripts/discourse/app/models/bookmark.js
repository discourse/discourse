import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import Category from "discourse/models/category";
import User from "discourse/models/user";
import { isRTL } from "discourse/lib/text-direction";
import { censor } from "pretty-text/censored-words";
import { emojiUnescape } from "discourse/lib/text";
import Site from "discourse/models/site";
import { longDate } from "discourse/lib/formatter";
import { none } from "@ember/object/computed";
import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import { formattedReminderTime } from "discourse/lib/bookmark";

const Bookmark = RestModel.extend({
  newBookmark: none("id"),

  @computed
  get url() {
    return getURL(`/bookmarks/${this.id}`);
  },

  destroy() {
    if (this.newBookmark) return Promise.resolve();

    return ajax(this.url, {
      type: "DELETE"
    });
  },

  @discourseComputed("highest_post_number", "url")
  lastPostUrl(highestPostNumber) {
    return this.urlForPostNumber(highestPostNumber);
  },

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = getURL(`/t/${this.topic_id}`);
    if (postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
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

    return I18n.messageFormat("topic.bumped_at_title_MF", {
      FIRST_POST: firstPost,
      CREATED_AT: createdAtDate,
      LAST_POST: lastPost,
      BUMPED_AT: bumpedAtDate
    });
  },

  @discourseComputed("title")
  fancyTitle(title) {
    let fancyTitle = censor(
      emojiUnescape(title) || "",
      Site.currentProp("censored_regexp")
    );

    if (this.siteSettings.support_mixed_text_direction) {
      const titleDir = isRTL(title) ? "rtl" : "ltr";
      return `<span dir="${titleDir}">${fancyTitle}</span>`;
    }
    return fancyTitle;
  },

  @discourseComputed("created_at")
  createdAt(created_at) {
    return new Date(created_at);
  },

  @discourseComputed("tags")
  visibleListTags(tags) {
    if (!tags || !this.siteSettings.suppress_overlapping_tags_in_list) {
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

  @discourseComputed("category_id")
  category(categoryId) {
    return Category.findById(categoryId);
  },

  @discourseComputed("reminder_at", "currentUser")
  formattedReminder(bookmarkReminderAt, currentUser) {
    return formattedReminderTime(
      bookmarkReminderAt,
      currentUser.resolvedTimezone(currentUser)
    ).capitalize();
  },

  loadItems() {
    return ajax(`/u/${this.user.username}/bookmarks.json`, { cache: "false" });
  },

  loadMore() {
    if (!this.more_bookmarks_url) {
      return Promise.resolve();
    }

    let moreUrl = this.more_bookmarks_url;
    if (moreUrl) {
      let [url, params] = moreUrl.split("?");
      moreUrl = url;
      if (params) {
        moreUrl += "?" + params;
      }
    }
    return ajax({ url: moreUrl });
  },

  @discourseComputed(
    "post_user_username",
    "post_user_avatar_template",
    "post_user_name"
  )
  postUser(post_user_username, avatarTemplate, name) {
    return User.create({
      username: post_user_username,
      avatar_template: avatarTemplate,
      name: name
    });
  }
});

Bookmark.reopenClass({
  create(args) {
    args = args || {};
    args.siteSettings = args.siteSettings || Discourse.SiteSettings;
    args.currentUser = args.currentUser || Discourse.currentUser;
    return this._super(args);
  }
});

export default Bookmark;
