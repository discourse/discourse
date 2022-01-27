import { applyDecorators, createWidget } from "discourse/widgets/widget";
import { later, next } from "@ember/runloop";
import { Promise } from "rsvp";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { h } from "virtual-dom";
import showModal from "discourse/lib/show-modal";
import { smallUserAtts } from "discourse/widgets/actions-summary";

const LIKE_ACTION = 2;
const VIBRATE_DURATION = 5;

const _builders = {};
let _extraButtons = {};
export let apiExtraButtons = {};
let _buttonsToRemove = {};

export function addButton(name, builder) {
  _extraButtons[name] = builder;
}

export function resetPostMenuExtraButtons() {
  _buttonsToRemove = {};
  apiExtraButtons = {};
  _extraButtons = {};
}

export function removeButton(name, callback) {
  if (callback) {
    _buttonsToRemove[name] = callback;
  } else {
    _buttonsToRemove[name] = () => {
      return true;
    };
  }
}

function registerButton(name, builder) {
  _builders[name] = builder;
}

export function buildButton(name, widget) {
  let { attrs, state, siteSettings, settings, currentUser } = widget;

  let shouldAddButton = true;

  if (_buttonsToRemove[name]) {
    shouldAddButton = !_buttonsToRemove[name](
      attrs,
      state,
      siteSettings,
      settings,
      currentUser
    );
  }

  let builder = _builders[name];

  if (shouldAddButton && builder) {
    let button = builder(attrs, state, siteSettings, settings, currentUser);
    if (button && !button.id) {
      button.id = name;
    }
    return button;
  }
}

registerButton("read-count", (attrs) => {
  if (attrs.showReadIndicator) {
    const count = attrs.readCount;
    if (count > 0) {
      return {
        action: "toggleWhoRead",
        title: "post.controls.read_indicator",
        className: "button-count read-indicator",
        contents: count,
        iconRight: true,
        addContainer: false,
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

function likeCount(attrs) {
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

    return {
      action: "toggleWhoLiked",
      title,
      className: `button-count like-count highlight-action ${additionalClass}`,
      contents: count,
      icon,
      iconRight: true,
      addContainer,
      titleOptions: { count: attrs.liked ? count - 1 : count },
    };
  }
}

registerButton("like-count", likeCount);

registerButton("like", (attrs) => {
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
    button.disabled = true;
  } else {
    button.title = attrs.liked
      ? "post.controls.undo_like"
      : "post.controls.like";
  }

  return button;
});

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
  const replyCount = attrs.replyCount;
  if (!replyCount) {
    return;
  }

  let action = "toggleRepliesBelow",
    icon = state.repliesShown ? "chevron-up" : "chevron-down";

  if (siteSettings.enable_filtered_replies_view) {
    action = "toggleFilteredRepliesView";
    icon = state.filteredRepliesShown ? "chevron-up" : "chevron-down";
  }

  // Omit replies if the setting `suppress_reply_directly_below` is enabled
  if (
    replyCount === 1 &&
    attrs.replyDirectlyBelow &&
    siteSettings.suppress_reply_directly_below
  ) {
    return;
  }

  return {
    action,
    icon,
    className: "show-replies",
    titleOptions: { count: replyCount },
    title: siteSettings.enable_filtered_replies_view
      ? state.filteredRepliesShown
        ? "post.view_all_posts"
        : "post.filtered_replies_hint"
      : "post.has_replies",
    labelOptions: { count: replyCount },
    label: attrs.mobileView ? "post.has_replies_count" : "post.has_replies",
    iconRight: !siteSettings.enable_filtered_replies_view || attrs.mobileView,
  };
});

registerButton("share", (attrs) => {
  return {
    action: "share",
    className: "share",
    title: "post.controls.share",
    icon: "d-post-share",
    data: {
      "share-url": attrs.shareUrl,
      "post-number": attrs.post_number,
    },
  };
});

registerButton("reply", (attrs, state, siteSettings, postMenuSettings) => {
  const args = {
    action: "replyToPost",
    title: "post.controls.reply",
    icon: "reply",
    className: "reply create fade-out",
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
  (attrs, _state, _siteSettings, _settings, currentUser) => {
    if (!attrs.canBookmark) {
      return;
    }

    let classNames = ["bookmark", "with-reminder"];
    let title = "bookmarks.not_bookmarked";
    let titleOptions = { name: "" };

    if (attrs.bookmarked) {
      classNames.push("bookmarked");

      if (attrs.bookmarkReminderAt) {
        let formattedReminder = formattedReminderTime(
          attrs.bookmarkReminderAt,
          currentUser.resolvedTimezone(currentUser)
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
      icon: attrs.bookmarkReminderAt ? "discourse-bookmark-clock" : "bookmark",
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

function replaceButton(buttons, find, replace) {
  const idx = buttons.indexOf(find);
  if (idx !== -1) {
    buttons[idx] = replace;
  }
}

export default createWidget("post-menu", {
  tagName: "section.post-menu-area.clearfix",

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
      adminVisible: false,
    };
  },

  buildKey: (attrs) => `post-menu-${attrs.id}`,

  attachButton(name) {
    let buttonAtts = buildButton(name, this);
    if (buttonAtts) {
      let button = this.attach(this.settings.buttonType, buttonAtts);
      if (buttonAtts.before) {
        let before = this.attachButton(buttonAtts.before);
        return h("div.double-button", [before, button]);
      } else if (buttonAtts.addContainer) {
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
      replaceButton(orderedButtons, "edit", "reply-small");
      replaceButton(orderedButtons, "reply", "wiki-edit");
    }

    orderedButtons.forEach((i) => {
      const button = this.attachButton(i, attrs);

      if (button) {
        allButtons.push(button);

        if (
          (attrs.yours && button.attrs && button.attrs.alwaysShowYours) ||
          (attrs.reviewableId && i === "flag") ||
          hiddenButtons.indexOf(i) === -1
        ) {
          visibleButtons.push(button);
        }
      }
    });

    if (!this.settings.collapseButtons) {
      visibleButtons = allButtons;
    }

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
    }

    Object.values(_extraButtons).forEach((builder) => {
      let shouldAddButton = true;

      if (_buttonsToRemove[name]) {
        shouldAddButton = !_buttonsToRemove[name](
          attrs,
          this.state,
          this.siteSettings,
          this.settings,
          this.currentUser
        );
      }

      if (shouldAddButton && builder) {
        const buttonAtts = builder(
          attrs,
          this.state,
          this.siteSettings,
          this.settings,
          this.currentUser
        );
        if (buttonAtts) {
          const { position, beforeButton, afterButton } = buttonAtts;
          delete buttonAtts.position;

          let button = this.attach(this.settings.buttonType, buttonAtts);

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
    if (state.adminVisible) {
      postControls.push(this.attach("post-admin-menu", attrs));
    }

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
        })
      );
    }

    return contents;
  },

  openAdminMenu() {
    this.state.adminVisible = true;
  },

  closeAdminMenu() {
    this.state.adminVisible = false;
  },

  showDeleteTopicModal() {
    showModal("delete-topic-disallowed");
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

    if (this.capabilities.canVibrate) {
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
      later(() => {
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
        state.likedUsers = users.map(smallUserAtts);
        state.total = users.totalRows;
      });
  },

  getWhoRead() {
    const { attrs, state } = this;

    return this.store.find("post-reader", { id: attrs.id }).then((users) => {
      state.readers = users.map(smallUserAtts);
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
