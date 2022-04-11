import { applyDecorators, createWidget } from "discourse/widgets/widget";
import {
  avatarUrl,
  formatUsername,
  translateSize,
} from "discourse/lib/utilities";
import getURL, { getURLWithCDN } from "discourse-common/lib/get-url";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import PostCooked from "discourse/widgets/post-cooked";
import { Promise } from "rsvp";
import RawHtml from "discourse/widgets/raw-html";
import bootbox from "bootbox";
import { dateNode } from "discourse/helpers/node";
import { h } from "virtual-dom";
import hbs from "discourse/widgets/hbs-compiler";
import { iconNode } from "discourse-common/lib/icon-library";
import { postTransformCallbacks } from "discourse/widgets/post-stream";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { relativeAgeMediumSpan } from "discourse/lib/formatter";
import { transformBasicPost } from "discourse/lib/transform-post";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import showModal from "discourse/lib/show-modal";
import { nativeShare } from "discourse/lib/pwa-utils";
import { wantsNewWindow } from "discourse/lib/intercept-click";

function transformWithCallbacks(post) {
  let transformed = transformBasicPost(post);
  postTransformCallbacks(transformed);
  return transformed;
}

export function avatarImg(wanted, attrs) {
  const size = translateSize(wanted);
  const url = avatarUrl(attrs.template, size);

  // We won't render an invalid url
  if (!url || url.length === 0) {
    return;
  }

  let title;
  if (!attrs.hideTitle) {
    title = attrs.name || formatUsername(attrs.username);
  }

  let alt = "";
  if (attrs.alt) {
    alt = I18n.t(attrs.alt);
  }

  let className =
    "avatar" + (attrs.extraClasses ? " " + attrs.extraClasses : "");

  const properties = {
    attributes: {
      alt,
      width: size,
      height: size,
      src: getURLWithCDN(url),
      title,
      "aria-label": title,
      loading: "lazy",
    },
    className,
  };

  return h("img", properties);
}

export function avatarFor(wanted, attrs, linkAttrs) {
  const attributes = {
    href: attrs.url,
    "data-user-card": attrs.username,
    "aria-hidden": true,
  };
  if (linkAttrs) {
    Object.assign(attributes, linkAttrs);
  }
  return h(
    "a",
    {
      className: `trigger-user-card ${attrs.className || ""}`,
      attributes,
    },
    avatarImg(wanted, attrs)
  );
}

createWidget("select-post", {
  tagName: "div.select-posts",

  html(attrs) {
    const buttons = [];

    if (!attrs.selected && attrs.post_number > 1) {
      if (attrs.replyCount > 0) {
        buttons.push(
          this.attach("button", {
            label: "topic.multi_select.select_replies.label",
            title: "topic.multi_select.select_replies.title",
            action: "selectReplies",
            className: "select-replies",
          })
        );
      }
      buttons.push(
        this.attach("button", {
          label: "topic.multi_select.select_below.label",
          title: "topic.multi_select.select_below.title",
          action: "selectBelow",
          className: "select-below",
        })
      );
    }

    const key = `topic.multi_select.${
      attrs.selected ? "selected" : "select"
    }_post`;
    buttons.push(
      this.attach("button", {
        label: key + ".label",
        title: key + ".title",
        action: "togglePostSelection",
        className: "select-post",
      })
    );

    return buttons;
  },
});

createWidget("reply-to-tab", {
  tagName: "a.reply-to-tab",
  buildKey: (attrs) => `reply-to-tab-${attrs.id}`,
  title: "post.in_reply_to",
  defaultState() {
    return { loading: false };
  },

  html(attrs, state) {
    const icon = state.loading ? h("div.spinner.small") : iconNode("share");

    return [
      icon,
      " ",
      avatarImg("small", {
        template: attrs.replyToAvatarTemplate,
        username: attrs.replyToUsername,
      }),
      " ",
      h("span", formatUsername(attrs.replyToUsername)),
    ];
  },

  click() {
    this.state.loading = true;
    this.sendWidgetAction("toggleReplyAbove").then(
      () => (this.state.loading = false)
    );
  },
});

createWidget("post-avatar-user-info", {
  tagName: "div.post-avatar-user-info",

  html(attrs) {
    return this.attach("poster-name", attrs);
  },
});

createWidget("post-avatar", {
  tagName: "div.topic-avatar",

  settings: {
    size: "large",
    displayPosterName: false,
  },

  html(attrs) {
    let body;
    let hideFromAnonUser =
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser;
    if (!attrs.user_id) {
      body = iconNode("far-trash-alt", { class: "deleted-user-avatar" });
    } else {
      body = avatarFor.call(
        this,
        this.settings.size,
        {
          template: attrs.avatar_template,
          username: attrs.username,
          name: attrs.name,
          url: attrs.usernameUrl,
          className: `main-avatar ${hideFromAnonUser ? "non-clickable" : ""}`,
          hideTitle: true,
        },
        {
          tabindex: "-1",
        }
      );
    }

    const postAvatarBody = [body];

    if (attrs.flair_url || attrs.flair_bg_color) {
      postAvatarBody.push(this.attach("avatar-flair", attrs));
    } else {
      const autoFlairAttrs = autoGroupFlairForUser(this.site, attrs);

      if (autoFlairAttrs) {
        postAvatarBody.push(this.attach("avatar-flair", autoFlairAttrs));
      }
    }

    const result = [h("div.post-avatar", postAvatarBody)];

    if (this.settings.displayPosterName) {
      result.push(this.attach("post-avatar-user-info", attrs));
    }

    return result;
  },
});

createWidget("post-locked-indicator", {
  tagName: "div.post-info.post-locked",
  template: hbs`{{d-icon "lock"}}`,
  title: () => I18n.t("post.locked"),
});

createWidget("post-email-indicator", {
  tagName: "div.post-info.via-email",

  title(attrs) {
    return attrs.isAutoGenerated
      ? I18n.t("post.via_auto_generated_email")
      : I18n.t("post.via_email");
  },

  buildClasses(attrs) {
    return attrs.canViewRawEmail ? "raw-email" : null;
  },

  html(attrs) {
    return attrs.isAutoGenerated
      ? iconNode("envelope")
      : iconNode("far-envelope");
  },

  click() {
    if (this.attrs.canViewRawEmail) {
      this.sendWidgetAction("showRawEmail");
    }
  },
});

function showReplyTab(attrs, siteSettings) {
  return (
    attrs.replyToUsername &&
    (!attrs.replyDirectlyAbove || !siteSettings.suppress_reply_directly_above)
  );
}

createWidget("post-meta-data", {
  tagName: "div.topic-meta-data",

  buildAttributes() {
    return {
      role: "heading",
      "aria-level": "2",
    };
  },

  settings: {
    displayPosterName: true,
  },

  html(attrs) {
    let postInfo = [];

    if (attrs.isWhisper) {
      postInfo.push(
        h(
          "div.post-info.whisper",
          {
            attributes: { title: I18n.t("post.whisper") },
          },
          iconNode("far-eye-slash")
        )
      );
    }

    if (attrs.via_email) {
      postInfo.push(this.attach("post-email-indicator", attrs));
    }

    if (attrs.locked) {
      postInfo.push(this.attach("post-locked-indicator", attrs));
    }

    if (attrs.version > 1 || attrs.wiki) {
      postInfo.push(this.attach("post-edits-indicator", attrs));
    }

    if (attrs.multiSelect) {
      postInfo.push(this.attach("select-post", attrs));
    }

    if (showReplyTab(attrs, this.siteSettings)) {
      postInfo.push(this.attach("reply-to-tab", attrs));
    }

    postInfo.push(
      h("div.post-info.post-date", this.attach("post-date-link", attrs))
    );

    postInfo.push(
      h(
        "div.read-state",
        {
          className: attrs.read ? "read" : null,
          attributes: {
            title: I18n.t("post.unread"),
          },
        },
        iconNode("circle")
      )
    );

    let result = [];
    if (this.settings.displayPosterName) {
      result.push(this.attach("poster-name", attrs));
    }
    result.push(h("div.post-infos", postInfo));

    return result;
  },
});

createWidget("expand-hidden", {
  tagName: "a.expand-hidden",

  html() {
    return I18n.t("post.show_hidden");
  },

  click() {
    this.sendWidgetAction("expandHidden");
  },
});

createWidget("post-date-link", {
  tagName: "a",

  buildAttributes(attrs) {
    const attributes = { href: attrs.shareUrl, class: "post-date" };
    if (attrs.lastWikiEdit) {
      attributes["class"] += " last-wiki-edit";
    }
    return attributes;
  },

  html(attrs) {
    const date = attrs.lastWikiEdit ? attrs.lastWikiEdit : attrs.created_at;
    return dateNode(new Date(date));
  },

  clickElement(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    const post = this.findAncestorModel();
    const topic = post.topic;
    const controller = showModal("share-topic", { model: topic.category });
    controller.setProperties({ topic, post });

    event.preventDefault();
  },
});

createWidget("expand-post-button", {
  tagName: "button.btn.expand-post",
  buildKey: (attrs) => `expand-post-button-${attrs.id}`,

  defaultState() {
    return { loadingExpanded: false };
  },

  html(attrs, state) {
    if (state.loadingExpanded) {
      return I18n.t("loading");
    } else {
      return [I18n.t("post.show_full"), "..."];
    }
  },

  click() {
    this.state.loadingExpanded = true;
    this.sendWidgetAction("expandFirstPost");
  },
});

createWidget("post-group-request", {
  buildKey: (attrs) => `post-group-request-${attrs.id}`,

  buildClasses() {
    return ["group-request"];
  },

  html(attrs) {
    const href = getURL(
      "/g/" + attrs.requestedGroupName + "/requests?filter=" + attrs.username
    );

    return h("a", { attributes: { href } }, I18n.t("groups.requests.handle"));
  },
});

createWidget("post-contents", {
  buildKey: (attrs) => `post-contents-${attrs.id}`,

  defaultState(attrs) {
    const defaultState = {
      expandedFirstPost: false,
      repliesBelow: [],
    };

    if (this.siteSettings.enable_filtered_replies_view) {
      const topicController = this.register.lookup("controller:topic");

      defaultState.filteredRepliesShown =
        topicController.replies_to_post_number === attrs.post_number.toString();
    }

    return defaultState;
  },

  buildClasses(attrs) {
    const classes = ["regular"];
    if (!this.state.repliesShown) {
      classes.push("contents");
    }
    if (showReplyTab(attrs, this.siteSettings)) {
      classes.push("avoid-tab");
    }
    return classes;
  },

  html(attrs, state) {
    let result = [
      new PostCooked(attrs, new DecoratorHelper(this), this.currentUser),
    ];

    if (attrs.requestedGroupName) {
      result.push(this.attach("post-group-request", attrs));
    }

    result = result.concat(applyDecorators(this, "after-cooked", attrs, state));

    if (attrs.cooked_hidden) {
      result.push(this.attach("expand-hidden", attrs));
    }

    if (!state.expandedFirstPost && attrs.expandablePost) {
      result.push(this.attach("expand-post-button", attrs));
    }

    const extraState = {
      state: {
        repliesShown: !!state.repliesBelow.length,
        filteredRepliesShown: state.filteredRepliesShown,
      },
    };
    result.push(this.attach("post-menu", attrs, extraState));

    const repliesBelow = state.repliesBelow;
    if (repliesBelow.length) {
      result.push(
        h("section.embedded-posts.bottom", [
          repliesBelow.map((p) => {
            return this.attach("embedded-post", p, {
              model: p.asPost,
              state: {
                role: "region",
                "aria-label": I18n.t("post.sr_embedded_reply_description", {
                  post_number: attrs.post_number,
                  username: p.username,
                }),
              },
            });
          }),
          this.attach("button", {
            title: "post.collapse",
            icon: "chevron-up",
            action: "toggleRepliesBelow",
            actionParam: "true",
            className: "btn collapse-up",
            translatedAriaLabel: I18n.t("post.sr_collapse_replies"),
          }),
        ])
      );
    }

    return result;
  },

  _date(attrs) {
    const lastWikiEdit =
      attrs.wiki && attrs.lastWikiEdit && new Date(attrs.lastWikiEdit);
    const createdAt = new Date(attrs.created_at);
    return lastWikiEdit ? lastWikiEdit : createdAt;
  },

  toggleFilteredRepliesView() {
    const post = this.findAncestorModel(),
      controller = this.register.lookup("controller:topic"),
      currentFilterPostNumber = post.get(
        "topic.postStream.filterRepliesToPostNumber"
      );

    if (
      currentFilterPostNumber &&
      currentFilterPostNumber === post.post_number
    ) {
      controller.send("cancelFilter", currentFilterPostNumber);
      this.state.filteredRepliesShown = false;
      return Promise.resolve();
    } else {
      this.state.filteredRepliesShown = true;

      return post
        .get("topic.postStream")
        .filterReplies(post.post_number, post.id)
        .then(() => {
          controller.updateQueryParams();
        });
    }
  },

  toggleRepliesBelow(goToPost = "false") {
    if (this.state.repliesBelow.length) {
      this.state.repliesBelow = [];
      if (goToPost === "true") {
        DiscourseURL.routeTo(
          `${this.attrs.topicUrl}/${this.attrs.post_number}`
        );
      }
      return;
    }

    const post = this.findAncestorModel();
    const topicUrl = post ? post.get("topic.url") : null;
    return this.store
      .find("post-reply", { postId: this.attrs.id })
      .then((posts) => {
        this.state.repliesBelow = posts.map((p) => {
          let result = transformWithCallbacks(p);

          // these would conflict with computed properties with identical names
          // in the post model if we kept them.
          delete result.new_user;
          delete result.deleted;
          delete result.shareUrl;
          delete result.firstPost;
          delete result.usernameUrl;

          result.customShare = `${topicUrl}/${p.post_number}`;
          result.asPost = this.store.createRecord("post", result);
          return result;
        });
      });
  },

  expandFirstPost() {
    const post = this.findAncestorModel();
    return post.expand().then(() => (this.state.expandedFirstPost = true));
  },

  share() {
    const post = this.findAncestorModel();
    nativeShare(this.capabilities, { url: post.shareUrl }).catch(() => {
      const topic = post.topic;
      const controller = showModal("share-topic", { model: topic.category });
      controller.setProperties({ topic, post });
    });
  },
});

createWidget("post-notice", {
  tagName: "div.post-notice",

  buildClasses(attrs) {
    const classes = [attrs.notice.type.replace(/_/g, "-")];

    if (
      new Date() - new Date(attrs.created_at) >
      this.siteSettings.old_post_notice_days * 86400000
    ) {
      classes.push("old");
    }

    return classes;
  },

  html(attrs) {
    if (attrs.notice.type === "custom") {
      return [
        iconNode("user-shield"),
        new RawHtml({ html: `<div>${attrs.notice.cooked}</div>` }),
      ];
    }

    const user =
      this.siteSettings.display_name_on_posts && prioritizeNameInUx(attrs.name)
        ? attrs.name
        : attrs.username;

    if (attrs.notice.type === "new_user") {
      return [
        iconNode("hands-helping"),
        h("p", I18n.t("post.notice.new_user", { user })),
      ];
    }

    if (attrs.notice.type === "returning_user") {
      const timeAgo = (new Date() - new Date(attrs.notice.lastPostedAt)) / 1000;
      const time = relativeAgeMediumSpan(timeAgo, true);
      return [
        iconNode("far-smile"),
        h("p", I18n.t("post.notice.returning_user", { user, time })),
      ];
    }
  },
});

createWidget("post-body", {
  tagName: "div.topic-body.clearfix",

  html(attrs, state) {
    const postContents = this.attach("post-contents", attrs);
    let result = [this.attach("post-meta-data", attrs)];
    result = result.concat(
      applyDecorators(this, "after-meta-data", attrs, state)
    );
    result.push(postContents);
    result.push(this.attach("actions-summary", attrs));
    result.push(this.attach("post-links", attrs));
    if (attrs.showTopicMap) {
      result.push(this.attach("topic-map", attrs));
    }

    return result;
  },
});

createWidget("post-article", {
  tagName: "article.boxed.onscreen-post",
  buildKey: (attrs) => `post-article-${attrs.id}`,

  defaultState() {
    return { repliesAbove: [] };
  },

  buildId(attrs) {
    return `post_${attrs.post_number}`;
  },

  buildClasses(attrs) {
    let classNames = [];
    if (attrs.via_email) {
      classNames.push("via-email");
    }
    if (attrs.isAutoGenerated) {
      classNames.push("is-auto-generated");
    }
    return classNames;
  },

  buildAttributes(attrs) {
    return {
      "aria-label": I18n.t("share.post", {
        postNumber: attrs.post_number,
        username: attrs.username,
      }),
      role: "region",
      "data-post-id": attrs.id,
      "data-topic-id": attrs.topicId,
      "data-user-id": attrs.user_id,
    };
  },

  html(attrs, state) {
    const rows = [
      h("span.tabLoc", {
        attributes: { "aria-hidden": true, tabindex: -1 },
      }),
    ];
    if (state.repliesAbove.length) {
      const replies = state.repliesAbove.map((p) => {
        return this.attach("embedded-post", p, {
          model: p.asPost,
          state: { above: true },
        });
      });

      rows.push(
        h(
          "div.row",
          h("section.embedded-posts.top.topic-body", [
            this.attach("button", {
              title: "post.collapse",
              icon: "chevron-down",
              action: "toggleReplyAbove",
              actionParam: "true",
              className: "btn collapse-down",
            }),
            replies,
          ])
        )
      );
    }

    if (!attrs.deleted_at && attrs.notice) {
      rows.push(h("div.row", [this.attach("post-notice", attrs)]));
    }

    rows.push(
      h("div.row", [
        this.attach("post-avatar", attrs),
        this.attach("post-body", attrs),
      ])
    );
    return rows;
  },

  _getTopicUrl() {
    const post = this.findAncestorModel();
    return post ? post.get("topic.url") : null;
  },

  toggleReplyAbove(goToPost = "false") {
    const replyPostNumber = this.attrs.reply_to_post_number;

    if (this.siteSettings.enable_filtered_replies_view) {
      const post = this.findAncestorModel();
      const controller = this.register.lookup("controller:topic");
      return post
        .get("topic.postStream")
        .filterUpwards(this.attrs.id)
        .then(() => {
          controller.updateQueryParams();
        });
    }

    // jump directly on mobile
    if (this.attrs.mobileView) {
      const topicUrl = this._getTopicUrl();
      if (topicUrl) {
        DiscourseURL.routeTo(`${topicUrl}/${replyPostNumber}`);
      }
      return Promise.resolve();
    }

    if (this.state.repliesAbove.length) {
      this.state.repliesAbove = [];
      if (goToPost === "true") {
        DiscourseURL.routeTo(
          `${this.attrs.topicUrl}/${this.attrs.post_number}`
        );
      }
      return Promise.resolve();
    } else {
      const topicUrl = this._getTopicUrl();
      return this.store
        .find("post-reply-history", { postId: this.attrs.id })
        .then((posts) => {
          this.state.repliesAbove = posts.map((p) => {
            let result = transformWithCallbacks(p);

            // We don't want to overwrite CPs - we are doing something a bit weird
            // here by creating a post object from a transformed post. They aren't
            // 100% the same.
            delete result.new_user;
            delete result.deleted;
            delete result.shareUrl;
            delete result.firstPost;
            delete result.usernameUrl;

            result.customShare = `${topicUrl}/${p.post_number}`;
            result.asPost = this.store.createRecord("post", result);
            return result;
          });
        });
    }
  },
});

let addPostClassesCallbacks = null;
export function addPostClassesCallback(callback) {
  addPostClassesCallbacks = addPostClassesCallbacks || [];
  addPostClassesCallbacks.push(callback);
}

export default createWidget("post", {
  buildKey: (attrs) => `post-${attrs.id}`,
  shadowTree: true,

  buildAttributes(attrs) {
    return attrs.height
      ? { style: `min-height: ${attrs.height}px` }
      : undefined;
  },

  buildId(attrs) {
    return attrs.cloaked ? `post_${attrs.post_number}` : undefined;
  },

  buildClasses(attrs) {
    if (attrs.cloaked) {
      return "cloaked-post";
    }
    const classNames = ["topic-post", "clearfix"];

    if (attrs.id === -1 || attrs.isSaving || attrs.staged) {
      classNames.push("staged");
    }
    if (attrs.selected) {
      classNames.push("selected");
    }
    if (attrs.topicOwner) {
      classNames.push("topic-owner");
    }
    if (this.currentUser && attrs.user_id === this.currentUser.id) {
      classNames.push("current-user-post");
    }
    if (attrs.groupModerator) {
      classNames.push("category-moderator");
    }
    if (attrs.hidden) {
      classNames.push("post-hidden");
    }
    if (attrs.deleted) {
      classNames.push("deleted");
    }
    if (attrs.primary_group_name) {
      classNames.push(`group-${attrs.primary_group_name}`);
    }
    if (attrs.wiki) {
      classNames.push(`wiki`);
    }
    if (attrs.isWhisper) {
      classNames.push("whisper");
    }
    if (attrs.isModeratorAction || (attrs.isWarning && attrs.firstPost)) {
      classNames.push("moderator");
    } else {
      classNames.push("regular");
    }
    if (addPostClassesCallbacks) {
      for (let i = 0; i < addPostClassesCallbacks.length; i++) {
        let pluginClasses = addPostClassesCallbacks[i].call(this, attrs);
        if (pluginClasses) {
          classNames.push.apply(classNames, pluginClasses);
        }
      }
    }
    return classNames;
  },

  html(attrs) {
    if (attrs.cloaked) {
      return "";
    }

    return this.attach("post-article", attrs);
  },

  toggleLike() {
    const post = this.model;
    const likeAction = post.get("likeAction");

    if (likeAction && likeAction.get("canToggle")) {
      return likeAction.togglePromise(post).then((result) => {
        this.appEvents.trigger("page:like-toggled", post, likeAction);
        return this._warnIfClose(result);
      });
    }
  },

  _warnIfClose(result) {
    if (!result || !result.acted) {
      return;
    }

    const kvs = this.keyValueStore;
    const lastWarnedLikes = kvs.get("lastWarnedLikes");

    // only warn once per day
    const yesterday = Date.now() - 1000 * 60 * 60 * 24;
    if (lastWarnedLikes && parseInt(lastWarnedLikes, 10) > yesterday) {
      return;
    }

    const { remaining, max } = result;
    const threshold = Math.ceil(max * 0.1);
    if (remaining === threshold) {
      bootbox.alert(I18n.t("post.few_likes_left"));
      kvs.set({ key: "lastWarnedLikes", value: Date.now() });
    }
  },
});
