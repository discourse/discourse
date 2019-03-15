import { applyDecorators, createWidget } from "discourse/widgets/widget";
import { avatarAtts } from "discourse/widgets/actions-summary";
import { h } from "virtual-dom";
import showModal from "discourse/lib/show-modal";

const LIKE_ACTION = 2;

function animateHeart($elem, start, end, complete) {
  if (Ember.testing) {
    return Ember.run(this, complete);
  }

  $elem
    .stop()
    .css("textIndent", start)
    .animate(
      { textIndent: end },
      {
        complete,
        step(now) {
          $(this)
            .css("transform", "scale(" + now + ")")
            .addClass("d-liked")
            .removeClass("d-unliked");
        },
        duration: 150
      },
      "linear"
    );
}

const _builders = {};
const _extraButtons = {};

export function addButton(name, builder) {
  _extraButtons[name] = builder;
}

function registerButton(name, builder) {
  _builders[name] = builder;
}

export function buildButton(name, widget) {
  let { attrs, state, siteSettings, settings } = widget;
  let builder = _builders[name];
  if (builder) {
    let button = builder(attrs, state, siteSettings, settings);
    if (button && !button.id) {
      button.id = name;
    }
    return button;
  }
}

registerButton("like", attrs => {
  if (!attrs.showLike) {
    return;
  }

  const className = attrs.liked
    ? "toggle-like has-like fade-out"
    : "toggle-like like";

  const button = {
    action: "like",
    icon: attrs.liked ? "d-liked" : "d-unliked",
    className
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

registerButton("like-count", attrs => {
  const count = attrs.likeCount;

  if (count > 0) {
    const title = attrs.liked
      ? count === 1
        ? "post.has_likes_title_only_you"
        : "post.has_likes_title_you"
      : "post.has_likes_title";
    const icon = attrs.yours ? "d-liked" : "";
    const additionalClass = attrs.yours ? "my-likes" : "regular-likes";

    return {
      action: "toggleWhoLiked",
      title,
      className: `like-count highlight-action ${additionalClass}`,
      contents: count,
      icon,
      iconRight: true,
      titleOptions: { count: attrs.liked ? count - 1 : count }
    };
  }
});

registerButton("flag", attrs => {
  if (attrs.canFlag && !attrs.hidden) {
    return {
      action: "showFlags",
      title: "post.controls.flag",
      icon: "flag",
      className: "create-flag"
    };
  }
});

registerButton("edit", attrs => {
  if (attrs.canEdit) {
    return {
      action: "editPost",
      className: "edit",
      title: "post.controls.edit",
      icon: "pencil-alt",
      alwaysShowYours: true
    };
  }
});

registerButton("reply-small", attrs => {
  if (!attrs.canCreatePost) {
    return;
  }

  const args = {
    action: "replyToPost",
    title: "post.controls.reply",
    icon: "reply",
    className: "reply"
  };

  return args;
});

registerButton("wiki-edit", attrs => {
  if (attrs.canEdit) {
    const args = {
      action: "editPost",
      className: "edit create",
      title: "post.controls.edit",
      icon: "pencil-square-o",
      alwaysShowYours: true
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

  // Omit replies if the setting `suppress_reply_directly_below` is enabled
  if (
    replyCount === 1 &&
    attrs.replyDirectlyBelow &&
    siteSettings.suppress_reply_directly_below
  ) {
    return;
  }

  return {
    action: "toggleRepliesBelow",
    className: "show-replies",
    icon: state.repliesShown ? "chevron-up" : "chevron-down",
    titleOptions: { count: replyCount },
    title: "post.has_replies",
    labelOptions: { count: replyCount },
    label: "post.has_replies",
    iconRight: true
  };
});

registerButton("share", attrs => {
  return {
    action: "share",
    className: "share",
    title: "post.controls.share",
    icon: "link",
    data: {
      "share-url": attrs.shareUrl,
      "post-number": attrs.post_number
    }
  };
});

registerButton("reply", (attrs, state, siteSettings, postMenuSettings) => {
  const args = {
    action: "replyToPost",
    title: "post.controls.reply",
    icon: "reply",
    className: "reply create fade-out"
  };

  if (!attrs.canCreatePost) {
    return;
  }

  if (postMenuSettings.showReplyTitleOnMobile || !attrs.mobileView) {
    args.label = "topic.reply.title";
  }

  return args;
});

registerButton("bookmark", attrs => {
  if (!attrs.canBookmark) {
    return;
  }

  let className = "bookmark";

  if (attrs.bookmarked) {
    className += " bookmarked";
  }

  return {
    id: attrs.bookmarked ? "unbookmark" : "bookmark",
    action: "toggleBookmark",
    title: attrs.bookmarked ? "bookmarks.created" : "bookmarks.not_bookmarked",
    className,
    icon: "bookmark"
  };
});

registerButton("admin", attrs => {
  if (!attrs.canManage && !attrs.canWiki) {
    return;
  }
  return {
    action: "openAdminMenu",
    title: "post.controls.admin",
    className: "show-post-admin-menu",
    icon: "wrench"
  };
});

registerButton("delete", attrs => {
  if (attrs.canRecoverTopic) {
    return {
      id: "recover_topic",
      action: "recoverPost",
      title: "topic.actions.recover",
      icon: "undo",
      className: "recover"
    };
  } else if (attrs.canDeleteTopic) {
    return {
      id: "delete_topic",
      action: "deletePost",
      title: "post.controls.delete_topic",
      icon: "far-trash-alt",
      className: "delete"
    };
  } else if (attrs.canRecover) {
    return {
      id: "recover",
      action: "recoverPost",
      title: "post.controls.undelete",
      icon: "undo",
      className: "recover"
    };
  } else if (attrs.canDelete) {
    return {
      id: "delete",
      action: "deletePost",
      title: "post.controls.delete",
      icon: "far-trash-alt",
      className: "delete"
    };
  } else if (!attrs.canDelete && attrs.firstPost && attrs.yours) {
    return {
      id: "delete_topic",
      action: "showDeleteTopicModal",
      title: "post.controls.delete_topic_disallowed",
      icon: "far-trash-alt",
      className: "delete"
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
    showReplyTitleOnMobile: false
  },

  defaultState() {
    return { collapsed: true, likedUsers: [], adminVisible: false };
  },

  buildKey: attrs => `post-menu-${attrs.id}`,

  attachButton(name) {
    let buttonAtts = buildButton(name, this);
    if (buttonAtts) {
      return this.attach(this.settings.buttonType, buttonAtts);
    }
  },

  menuItems() {
    let result = this.siteSettings.post_menu.split("|");
    return result;
  },

  html(attrs, state) {
    const { currentUser, keyValueStore, siteSettings } = this;

    const hiddenSetting = siteSettings.post_menu_hidden_items || "";
    const hiddenButtons = hiddenSetting
      .split("|")
      .filter(s => !attrs.bookmarked || s !== "bookmark");

    if (currentUser && keyValueStore) {
      const likedPostId = keyValueStore.getInt("likedPostId");
      if (likedPostId === attrs.id) {
        keyValueStore.remove("likedPostId");
        Ember.run.next(() => this.sendWidgetAction("toggleLike"));
      }
    }

    const allButtons = [];
    let visibleButtons = [];

    const orderedButtons = this.menuItems();

    // If the post is a wiki, make Edit more prominent
    if (attrs.wiki && attrs.canEdit) {
      replaceButton(orderedButtons, "edit", "reply-small");
      replaceButton(orderedButtons, "reply", "wiki-edit");
    }

    orderedButtons
      .filter(x => x !== "like-count" && x !== "like")
      .forEach(i => {
        const button = this.attachButton(i, attrs);

        if (button) {
          allButtons.push(button);

          if (
            (attrs.yours && button.attrs.alwaysShowYours) ||
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
        icon: "ellipsis-h"
      });
      visibleButtons.splice(visibleButtons.length - 1, 0, showMore);
    }

    visibleButtons.unshift(
      h("div.like-button", [
        this.attachButton("like-count", attrs),
        this.attachButton("like", attrs)
      ])
    );

    Object.values(_extraButtons).forEach(builder => {
      if (builder) {
        const buttonAtts = builder(attrs, this.state, this.siteSettings);
        if (buttonAtts) {
          const { position, beforeButton } = buttonAtts;
          delete buttonAtts.position;

          let button = this.attach(this.settings.buttonType, buttonAtts);

          if (beforeButton) {
            button = h("span", [beforeButton(h), button]);
          }

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

    let extraControls = applyDecorators(this, "extra-controls", attrs, state);
    postControls.push(h("div.actions", visibleButtons.concat(extraControls)));
    if (state.adminVisible) {
      postControls.push(this.attach("post-admin-menu", attrs));
    }

    const contents = [h("nav.post-controls.clearfix", postControls)];
    if (state.likedUsers.length) {
      const remaining = state.total - state.likedUsers.length;
      contents.push(
        this.attach("small-user-list", {
          users: state.likedUsers,
          addSelf: attrs.liked && remaining === 0,
          listClassName: "who-liked",
          description:
            remaining > 0
              ? "post.actions.people.like_capped"
              : "post.actions.people.like",
          count: remaining
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
    if (!this.state.likedUsers.length) {
      return this.getWhoLiked();
    }
  },

  like() {
    const { attrs, currentUser, keyValueStore } = this;

    if (!currentUser) {
      keyValueStore &&
        keyValueStore.set({ key: "likedPostId", value: attrs.id });
      return this.sendWidgetAction("showLogin");
    }

    if (attrs.liked) {
      return this.sendWidgetAction("toggleLike");
    }

    const $heart = $(`[data-post-id=${attrs.id}] .toggle-like .d-icon`);
    $heart.closest("button").addClass("has-like");

    const scale = [1.0, 1.5];
    return new Ember.RSVP.Promise(resolve => {
      animateHeart($heart, scale[0], scale[1], () => {
        animateHeart($heart, scale[1], scale[0], () => {
          this.sendWidgetAction("toggleLike").then(() => resolve());
        });
      });
    });
  },

  refreshLikes() {
    if (this.state.likedUsers.length) {
      return this.getWhoLiked();
    }
  },

  getWhoLiked() {
    const { attrs, state } = this;

    return this.store
      .find("post-action-user", {
        id: attrs.id,
        post_action_type_id: LIKE_ACTION
      })
      .then(users => {
        state.likedUsers = users.map(avatarAtts);
        state.total = users.totalRows;
      });
  },

  toggleWhoLiked() {
    const state = this.state;
    if (state.likedUsers.length) {
      state.likedUsers = [];
    } else {
      return this.getWhoLiked();
    }
  }
});
