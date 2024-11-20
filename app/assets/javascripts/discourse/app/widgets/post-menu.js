import { next } from "@ember/runloop";
import { hbs } from "ember-cli-htmlbars";
import { Promise } from "rsvp";
import { h } from "virtual-dom";
import AdminPostMenu from "discourse/components/admin-post-menu";
import DeleteTopicDisallowedModal from "discourse/components/modal/delete-topic-disallowed";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { recentlyCopied, showAlert } from "discourse/lib/post-action-feedback";
import { smallUserAttrs } from "discourse/lib/user-list-attrs";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { applyDecorators, createWidget } from "discourse/widgets/widget";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";

const LIKE_ACTION = 2;
const VIBRATE_DURATION = 5;

const _builders = {};
export let apiExtraButtons = {};
let _extraButtons = {};
let _buttonsToRemoveCallbacks = {};
let _buttonsToReplace = {};

export function addButton(name, builder) {
  _extraButtons[name] = builder;
}

export function resetPostMenuExtraButtons() {
  for (const key of Object.keys(apiExtraButtons)) {
    delete apiExtraButtons[key];
  }

  _extraButtons = {};
  _buttonsToRemoveCallbacks = {};
  _buttonsToReplace = {};
}

export function removeButton(name, callback) {
  // 🏌️
  _buttonsToRemoveCallbacks[name] ??= [];
  _buttonsToRemoveCallbacks[name].push(callback || (() => true));
}

export function replaceButton(name, replaceWith) {
  _buttonsToReplace[name] = replaceWith;
}

function registerButton(name, builder) {
  _builders[name] = builder;
}

export function buildButton(name, widget) {
  let { attrs, state, siteSettings, settings, currentUser } = widget;

  // Return early if the button is supposed to be removed via the plugin API
  if (
    _buttonsToRemoveCallbacks[name] &&
    _buttonsToRemoveCallbacks[name].some((c) =>
      c(attrs, state, siteSettings, settings, currentUser)
    )
  ) {
    return;
  }

  // Look for a button replacement, build and return widget attrs if present
  let replacement = _buttonsToReplace[name];
  if (replacement && replacement?.shouldRender(widget)) {
    return {
      replaced: true,
      name: replacement.name,
      attrs: replacement.buildAttrs(widget),
    };
  }

  let builder = _builders[name];
  if (builder) {
    let button = builder(attrs, state, siteSettings, settings, currentUser);
    if (button && !button.id) {
      button.id = name;
    }
    return button;
  }
}

registerButton("read-count", (attrs, state) => {
  if (attrs.showReadIndicator) {
    const count = attrs.readCount;
    if (count > 0) {
      let ariaPressed = (state?.readers?.length > 0).toString();
      return {
        action: "toggleWhoRead",
        title: "post.controls.read_indicator",
        className: "button-count read-indicator",
        contents: count,
        iconRight: true,
        addContainer: false,
        translatedAriaLabel: I18n.t("post.sr_post_read_count_button", {
          count,
        }),
        ariaPressed,
      };
    }
  }
});

registerButton("read", (attrs) => {
  const readBySomeone = attrs.readCount > 0;
  if (attrs.showReadIndicator && readBySomeone) {
    return {
      action: "toggleWhoRead",
      title: "post.controls.read_indicator",
      icon: "book-reader",
      before: "read-count",
      addContainer: false,
    };
  }
});

function likeCount(attrs, state) {
  const count = attrs.likeCount;

  if (count > 0) {
    const title = attrs.liked
      ? count === 1
        ? "post.has_likes_title_only_you"
        : "post.has_likes_title_you"
      : "post.has_likes_title";
    let icon = attrs.yours ? "d-liked" : "";
    let addContainer = attrs.yours;
    const additionalClass = attrs.yours ? "my-likes" : "regular-likes";

    if (!attrs.showLike) {
      icon = attrs.yours ? "d-liked" : "d-unliked";
      addContainer = true;
    }

    let ariaPressed = (state?.likedUsers?.length > 0).toString();

    return {
      action: "toggleWhoLiked",
      title,
      className: `button-count like-count highlight-action ${additionalClass}`,
      contents: count,
      icon,
      iconRight: true,
      addContainer,
      titleOptions: { count: attrs.liked ? count - 1 : count },
      translatedAriaLabel: I18n.t("post.sr_post_like_count_button", { count }),
      ariaPressed,
    };
  }
}

registerButton("like-count", likeCount);

registerButton(
  "like",
  (attrs, _state, _siteSettings, _settings, currentUser) => {
    if (!attrs.showLike) {
      return likeCount(attrs);
    }

    const className = attrs.liked
      ? "toggle-like has-like fade-out"
      : "toggle-like like";

    const button = {
      action: "like",
      icon: attrs.liked ? "d-liked" : "d-unliked",
      className,
      before: "like-count",
      data: {
        "post-id": attrs.id,
      },
    };

    // If the user has already liked the post and doesn't have permission
    // to undo that operation, then indicate via the title that they've liked it
    // and disable the button. Otherwise, set the title even if the user
    // is anonymous (meaning they don't currently have permission to like);
    // this is important for accessibility.
    if (attrs.liked && !attrs.canToggleLike) {
      button.title = "post.controls.has_liked";
    } else {
      button.title = attrs.liked
        ? "post.controls.undo_like"
        : "post.controls.like";
    }
    if (currentUser && !attrs.canToggleLike) {
      button.disabled = true;
    }
    return button;
  }
);

registerButton("flag-count", (attrs) => {
  let className = "button-count";
  if (attrs.reviewableScorePendingCount > 0) {
    className += " has-pending";
  }
  return {
    className,
    contents: h("span", attrs.reviewableScoreCount.toString()),
    url: `/review/${attrs.reviewableId}`,
  };
});

registerButton("flag", (attrs) => {
  if (attrs.reviewableId || (attrs.canFlag && !attrs.hidden)) {
    let button = {
      action: "showFlags",
      title: "post.controls.flag",
      icon: "flag",
      className: "create-flag",
    };
    if (attrs.reviewableId) {
      button.before = "flag-count";
    }
    return button;
  }
});

registerButton("edit", (attrs) => {
  if (attrs.canEdit) {
    return {
      action: "editPost",
      className: "edit",
      title: "post.controls.edit",
      icon: "pencil-alt",
      alwaysShowYours: true,
    };
  }
});

registerButton("reply-small", (attrs) => {
  if (!attrs.canCreatePost) {
    return;
  }

  const args = {
    action: "replyToPost",
    title: "post.controls.reply",
    icon: "reply",
    className: "reply",
    translatedAriaLabel: I18n.t("post.sr_reply_to", {
      post_number: attrs.post_number,
      username: attrs.username,
    }),
  };

  return args;
});

registerButton("wiki-edit", (attrs) => {
  if (attrs.canEdit) {
    const args = {
      action: "editPost",
      className: "edit create",
      title: "post.controls.edit",
      icon: "far-edit",
      alwaysShowYours: true,
    };
    if (!attrs.mobileView) {
      args.label = "post.controls.edit_action";
    }
    return args;
  }
});

registerButton("replies", (attrs, state, siteSettings) => {
  const count = attrs.replyCount;

  if (!count) {
    return;
  }

  let title;
  let action = "toggleRepliesBelow";
  let icon = state.repliesShown ? "chevron-up" : "chevron-down";

  if (siteSettings.enable_filtered_replies_view) {
    action = "toggleFilteredRepliesView";
    icon = state.filteredRepliesShown ? "chevron-up" : "chevron-down";
    title = state.filteredRepliesShown
      ? "post.view_all_posts"
      : "post.filtered_replies_hint";
  }

  // Omit replies if the setting `suppress_reply_directly_below` is enabled
  if (
    count === 1 &&
    attrs.replyDirectlyBelow &&
    siteSettings.suppress_reply_directly_below
  ) {
    return;
  }

  let ariaPressed, ariaExpanded;

  if (!siteSettings.enable_filtered_replies_view) {
    ariaPressed = state.repliesShown.toString();
    ariaExpanded = state.repliesShown.toString();
  }

  return {
    action,
    icon,
    className: "show-replies",
    titleOptions: { count },
    title,
    labelOptions: { count },
    label: attrs.mobileView ? "post.has_replies_count" : "post.has_replies",
    iconRight: !siteSettings.enable_filtered_replies_view || attrs.mobileView,
    disabled: !!attrs.deleted,
    translatedAriaLabel: I18n.t("post.sr_expand_replies", { count }),
    ariaExpanded,
    ariaPressed,
    ariaControls: `embedded-posts__bottom--${attrs.post_number}`,
  };
});

registerButton("share", () => {
  return {
    action: "share",
    icon: "d-post-share",
    className: "share",
    title: "post.controls.share",
  };
});

registerButton("copyLink", () => {
  return {
    action: "copyLink",
    icon: "d-post-share",
    className: "post-action-menu__copy-link",
    title: "post.controls.copy_title",
  };
});

registerButton("reply", (attrs, state, siteSettings, postMenuSettings) => {
  const args = {
    action: "replyToPost",
    title: "post.controls.reply",
    icon: "reply",
    className: "reply create fade-out",
    translatedAriaLabel: I18n.t("post.sr_reply_to", {
      post_number: attrs.post_number,
      username: attrs.username,
    }),
  };

  if (!attrs.canCreatePost) {
    return;
  }

  if (postMenuSettings.showReplyTitleOnMobile || !attrs.mobileView) {
    args.label = "topic.reply.title";
  }

  return args;
});

registerButton(
  "bookmark",
  (attrs, _state, siteSettings, _settings, currentUser) => {
    if (!attrs.canBookmark) {
      return;
    }

    let classNames = ["bookmark"];
    let title = "bookmarks.not_bookmarked";
    let titleOptions = { name: "" };

    if (attrs.bookmarked) {
      classNames.push("bookmarked");

      if (attrs.bookmarkReminderAt) {
        classNames.push("with-reminder");

        let formattedReminder = formattedReminderTime(
          attrs.bookmarkReminderAt,
          currentUser.user_option.timezone
        );
        title = "bookmarks.created_with_reminder";
        titleOptions.date = formattedReminder;
      } else {
        title = "bookmarks.created";
      }

      if (attrs.bookmarkName) {
        titleOptions.name = attrs.bookmarkName;
      }
    }

    return {
      id: attrs.bookmarked ? "unbookmark" : "bookmark",
      action: "toggleBookmark",
      title,
      titleOptions,
      className: classNames.join(" "),
      icon: attrs.bookmarkReminderAt ? WITH_REMINDER_ICON : NO_REMINDER_ICON,
    };
  }
);

registerButton("admin", (attrs) => {
  if (!attrs.canManage && !attrs.canWiki && !attrs.canEditStaffNotes) {
    return;
  }

  return {
    action: "openAdminMenu",
    title: "post.controls.admin",
    className: "show-post-admin-menu",
    icon: "wrench",
    sendActionEvent: true,
  };
});

registerButton("delete", (attrs) => {
  if (attrs.canRecoverTopic) {
    return {
      id: "recover_topic",
      action: "recoverPost",
      title: "topic.actions.recover",
      icon: "undo",
      className: "recover",
    };
  } else if (attrs.canDeleteTopic) {
    return {
      id: "delete_topic",
      action: "deletePost",
      title: "post.controls.delete_topic",
      icon: "far-trash-alt",
      className: "delete",
    };
  } else if (attrs.canRecover) {
    return {
      id: "recover",
      action: "recoverPost",
      title: "post.controls.undelete",
      icon: "undo",
      className: "recover",
    };
  } else if (attrs.canDelete) {
    return {
      id: "delete",
      action: "deletePost",
      title: "post.controls.delete",
      icon: "far-trash-alt",
      className: "delete",
    };
  } else if (attrs.showFlagDelete) {
    return {
      id: "delete_topic",
      action: "showDeleteTopicModal",
      title: "post.controls.delete_topic_disallowed",
      icon: "far-trash-alt",
      className: "delete",
    };
  }
});

function _replaceButton(buttons, find, replace) {
  const idx = buttons.indexOf(find);
  if (idx !== -1) {
    buttons[idx] = replace;
  }
}

export default createWidget("post-menu", {
  tagName: "section.post-menu-area.clearfix",
  services: ["modal", "menu"],

  settings: {
    collapseButtons: true,
    buttonType: "flat-button",
    showReplyTitleOnMobile: false,
  },

  defaultState() {
    return {
      collapsed: true,
      likedUsers: [],
      readers: [],
    };
  },

  buildKey: (attrs) => `post-menu-${attrs.id}`,

  attachButton(name) {
    let buttonAttrs = buildButton(name, this);

    if (buttonAttrs?.component) {
      return [
        new RenderGlimmer(
          this,
          buttonAttrs.tagName,
          hbs`<@data.component
            @permanentlyDeletePost={{@data.permanentlyDeletePost}}
            @lockPost={{@data.lockPost}}
            @unlockPost={{@data.unlockPost}}
            @grantBadge={{@data.grantBadge}}
            @rebakePost={{@data.rebakePost}}
            @toggleWiki={{@data.toggleWiki}}
            @changePostOwner={{@data.changePostOwner}}
            @changeNotice={{@data.changeNotice}}
            @togglePostType={{@data.togglePostType}}
            @unhidePost={{@data.unhidePost}}
            @showPagePublish={{@data.showPagePublish}}
            @post={{@data.post}}
            @transformedPost={{@data.transformedPost}}
            @scheduleRerender={{@data.scheduleRerender}}
          />`,
          {
            component: buttonAttrs.component,
            transformedPost: this.attrs,
            post: this.findAncestorModel(),
            permanentlyDeletePost: () =>
              this.sendWidgetAction("permanentlyDeletePost"),
            lockPost: () => this.sendWidgetAction("lockPost"),
            unlockPost: () => this.sendWidgetAction("unlockPost"),
            grantBadge: () => this.sendWidgetAction("grantBadge"),
            rebakePost: () => this.sendWidgetAction("rebakePost"),
            toggleWiki: () => this.sendWidgetAction("toggleWiki"),
            changePostOwner: () => this.sendWidgetAction("changePostOwner"),
            changeNotice: () => this.sendWidgetAction("changeNotice"),
            togglePostType: () => this.sendWidgetAction("togglePostType"),
            scheduleRerender: () => this.scheduleRerender(),
          }
        ),
      ];
    }

    // If the button is replaced via the plugin API, we need to render the
    // replacement rather than a button
    if (buttonAttrs?.replaced) {
      return this.attach(buttonAttrs.name, buttonAttrs.attrs);
    }

    if (buttonAttrs) {
      let button = this.attach(this.settings.buttonType, buttonAttrs);
      if (buttonAttrs.before) {
        let before = this.attachButton(buttonAttrs.before);
        return h("div.double-button", [before, button]);
      } else if (buttonAttrs.addContainer) {
        return h("div.double-button", [button]);
      }

      return button;
    }
  },

  menuItems() {
    return this.siteSettings.post_menu.split("|").filter(Boolean);
  },

  html(attrs, state) {
    const { currentUser, keyValueStore, siteSettings } = this;

    const hiddenSetting = siteSettings.post_menu_hidden_items || "";
    const hiddenButtons = hiddenSetting
      .split("|")
      .filter((s) => !attrs.bookmarked || s !== "bookmark");

    if (currentUser && keyValueStore) {
      const likedPostId = keyValueStore.getInt("likedPostId");
      if (likedPostId === attrs.id) {
        keyValueStore.remove("likedPostId");
        next(() => this.sendWidgetAction("toggleLike"));
      }
    }

    const allButtons = [];
    let visibleButtons = [];

    // filter menu items based on site settings
    const orderedButtons = this.menuItems();

    // If the post is a wiki, make Edit more prominent
    if (attrs.wiki && attrs.canEdit) {
      _replaceButton(orderedButtons, "edit", "reply-small");
      _replaceButton(orderedButtons, "reply", "wiki-edit");
    }

    orderedButtons.forEach((i) => {
      const button = this.attachButton(i, attrs);

      if (button) {
        allButtons.push(button);

        if (
          (attrs.yours && button.attrs && button.attrs.alwaysShowYours) ||
          (attrs.reviewableId && i === "flag") ||
          !hiddenButtons.includes(i)
        ) {
          visibleButtons.push(button);
        }
      }
    });

    if (!this.settings.collapseButtons) {
      visibleButtons = allButtons;
    }

    let hasShowMoreButton = false;
    // Only show ellipsis if there is more than one button hidden
    // if there are no more buttons, we are not collapsed
    if (!state.collapsed || allButtons.length <= visibleButtons.length + 1) {
      visibleButtons = allButtons;
      if (state.collapsed) {
        state.collapsed = false;
      }
    } else {
      const showMore = this.attach("flat-button", {
        action: "showMoreActions",
        title: "show_more",
        className: "show-more-actions",
        icon: "ellipsis-h",
      });
      visibleButtons.splice(visibleButtons.length - 1, 0, showMore);
      hasShowMoreButton = true;
    }

    Object.values(_extraButtons).forEach((builder) => {
      let shouldAddButton = true;

      if (_buttonsToRemoveCallbacks[name]) {
        shouldAddButton = !_buttonsToRemoveCallbacks[name].some((c) =>
          c(
            attrs,
            this.state,
            this.siteSettings,
            this.settings,
            this.currentUser
          )
        );
      }

      if (shouldAddButton && builder) {
        const buttonAttrs = builder(
          attrs,
          this.state,
          this.siteSettings,
          this.settings,
          this.currentUser
        );
        if (buttonAttrs) {
          const { position, beforeButton, afterButton } = buttonAttrs;
          delete buttonAttrs.position;
          let button;

          if (typeof buttonAttrs.action === "function") {
            const original = buttonAttrs.action;
            const self = this;

            buttonAttrs.action = async function (post) {
              let showFeedback = null;

              if (buttonAttrs.className) {
                showFeedback = (messageKey) => {
                  showAlert(post.id, buttonAttrs.className, messageKey);
                };
              }

              const postAttrs = {
                post,
                showFeedback,
              };

              if (
                !buttonAttrs.className ||
                !recentlyCopied(post.id, buttonAttrs.actionClass)
              ) {
                self.sendWidgetAction(original, postAttrs);
              }
            };
          }

          button = this.attach(this.settings.buttonType, buttonAttrs);

          const content = [];
          if (beforeButton) {
            content.push(beforeButton(h));
          }
          content.push(button);
          if (afterButton) {
            content.push(afterButton(h));
          }
          button = h("span.extra-buttons", content);

          if (button) {
            switch (position) {
              case "first":
                visibleButtons.unshift(button);
                break;
              case "second":
                visibleButtons.splice(1, 0, button);
                break;
              case "second-last-hidden":
                if (!state.collapsed) {
                  visibleButtons.splice(visibleButtons.length - 2, 0, button);
                }
                break;
              default:
                visibleButtons.push(button);
                break;
            }
          }
        }
      }
    });

    const postControls = [];

    const repliesButton = this.attachButton("replies", attrs);
    if (repliesButton) {
      postControls.push(repliesButton);
    }

    const extraPostControls = applyDecorators(
      this,
      "extra-post-controls",
      attrs,
      state
    );

    postControls.push(extraPostControls);

    const extraControls = applyDecorators(this, "extra-controls", attrs, state);
    const beforeExtraControls = applyDecorators(
      this,
      "before-extra-controls",
      attrs,
      state
    );

    const controlsButtons = [
      ...beforeExtraControls,
      ...visibleButtons,
      ...extraControls,
    ];

    postControls.push(h("div.actions", controlsButtons));

    const contents = [
      h(
        "nav.post-controls" +
          (this.state.collapsed ? ".collapsed" : ".expanded") +
          (siteSettings.enable_filtered_replies_view
            ? ".replies-button-visible"
            : ""),
        postControls
      ),
    ];

    if (state.readers.length) {
      const remaining = state.totalReaders - state.readers.length;
      const description =
        remaining > 0
          ? "post.actions.people.read_capped"
          : "post.actions.people.read";
      const count = remaining > 0 ? remaining : state.totalReaders;

      contents.push(
        this.attach("small-user-list", {
          users: state.readers,
          addSelf: false,
          listClassName: "who-read",
          description,
          count,
          ariaLabel: I18n.t(
            "post.actions.people.sr_post_readers_list_description"
          ),
        })
      );
    }

    if (state.likedUsers.length) {
      const remaining = state.total - state.likedUsers.length;
      const description =
        remaining > 0
          ? "post.actions.people.like_capped"
          : "post.actions.people.like";
      const count = remaining > 0 ? remaining : state.total;

      contents.push(
        this.attach("small-user-list", {
          users: state.likedUsers,
          addSelf: attrs.liked && remaining === 0,
          listClassName: "who-liked",
          description,
          count,
          ariaLabel: I18n.t(
            "post.actions.people.sr_post_likers_list_description"
          ),
        })
      );
    }
    if (hasShowMoreButton) {
      contents.push(this.attach("post-user-tip-shim"));
    }
    return contents;
  },

  openAdminMenu(event) {
    this.menu.show(event.target, {
      identifier: "admin-post-menu",
      component: AdminPostMenu,
      modalForMobile: true,
      autofocus: true,
      data: {
        scheduleRerender: this.scheduleRerender.bind(this),
        transformedPost: this.attrs,
        post: this.findAncestorModel(),
        permanentlyDeletePost: () =>
          this.sendWidgetAction("permanentlyDeletePost"),
        lockPost: () => this.sendWidgetAction("lockPost"),
        unlockPost: () => this.sendWidgetAction("unlockPost"),
        grantBadge: () => this.sendWidgetAction("grantBadge"),
        rebakePost: () => this.sendWidgetAction("rebakePost"),
        toggleWiki: () => this.sendWidgetAction("toggleWiki"),
        changePostOwner: () => this.sendWidgetAction("changePostOwner"),
        changeNotice: () => this.sendWidgetAction("changeNotice"),
        togglePostType: () => this.sendWidgetAction("togglePostType"),
        unhidePost: () => this.sendWidgetAction("unhidePost"),
        showPagePublish: () => this.sendWidgetAction("showPagePublish"),
      },
    });
  },

  showDeleteTopicModal() {
    this.modal.show(DeleteTopicDisallowedModal);
  },

  showMoreActions() {
    this.state.collapsed = false;
    const likesPromise = !this.state.likedUsers.length
      ? this.getWhoLiked()
      : Promise.resolve();

    return likesPromise.then(() => {
      if (!this.state.readers.length && this.attrs.showReadIndicator) {
        return this.getWhoRead();
      }
    });
  },

  like() {
    const { attrs, currentUser, keyValueStore } = this;

    if (!currentUser) {
      keyValueStore &&
        keyValueStore.set({ key: "likedPostId", value: attrs.id });
      return this.sendWidgetAction("showLogin");
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(VIBRATE_DURATION);
    }

    if (attrs.liked) {
      return this.sendWidgetAction("toggleLike");
    }

    const heart = document.querySelector(
      `.toggle-like[data-post-id="${attrs.id}"] .d-icon`
    );
    heart.closest(".toggle-like").classList.add("has-like");
    heart.classList.add("heart-animation");

    return new Promise((resolve) => {
      discourseLater(() => {
        this.sendWidgetAction("toggleLike").then(() => resolve());
      }, 400);
    });
  },

  refreshLikes() {
    if (this.state.likedUsers.length) {
      return this.getWhoLiked();
    }
  },

  refreshReaders() {
    if (this.state.readers.length) {
      return this.getWhoRead();
    }
  },

  getWhoLiked() {
    const { attrs, state } = this;
    return this.store
      .find("post-action-user", {
        id: attrs.id,
        post_action_type_id: LIKE_ACTION,
      })
      .then((users) => {
        state.likedUsers = users.map(smallUserAttrs);
        state.total = users.totalRows;
      });
  },

  getWhoRead() {
    const { attrs, state } = this;

    return this.store.find("post-reader", { id: attrs.id }).then((users) => {
      state.readers = users.map(smallUserAttrs);
      state.totalReaders = users.totalRows;
    });
  },

  toggleWhoLiked() {
    const state = this.state;
    if (state.likedUsers.length) {
      state.likedUsers = [];
    } else {
      return this.getWhoLiked();
    }
  },

  toggleWhoRead() {
    const state = this.state;
    if (this.state.readers.length) {
      state.readers = [];
    } else {
      return this.getWhoRead();
    }
  },
});
