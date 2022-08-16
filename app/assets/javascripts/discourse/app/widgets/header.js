import DiscourseURL, { userPath } from "discourse/lib/url";
import I18n from "I18n";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { schedule } from "@ember/runloop";
import { scrollTop } from "discourse/mixins/scroll-top";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

let _extraHeaderIcons = [];

export function addToHeaderIcons(icon) {
  _extraHeaderIcons.push(icon);
}

export function clearExtraHeaderIcons() {
  _extraHeaderIcons = [];
}

const dropdown = {
  buildClasses(attrs) {
    let classes = attrs.classNames || [];
    if (attrs.active) {
      classes.push("active");
    }

    return classes;
  },

  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    if (!this.attrs.active) {
      this.sendWidgetAction(this.attrs.action);
    }
  },
};

createWidget("header-notifications", {
  settings: {
    avatarSize: "medium",
  },

  html(attrs) {
    const { user } = attrs;

    let avatarAttrs = {
      template: user.get("avatar_template"),
      username: user.get("username"),
    };

    if (this.siteSettings.enable_names) {
      avatarAttrs.name = user.get("name");
    }

    const contents = [
      avatarImg(
        this.settings.avatarSize,
        Object.assign(
          {
            alt: "user.avatar.header_title",
          },
          addExtraUserClasses(user, avatarAttrs)
        )
      ),
    ];

    if (this.currentUser.status) {
      contents.push(this.attach("user-status-bubble", this.currentUser.status));
    }

    if (user.isInDoNotDisturb()) {
      contents.push(h("div.do-not-disturb-background", iconNode("moon")));
    } else {
      if (this.currentUser.redesigned_user_menu_enabled) {
        const unread = user.all_unread_notifications_count || 0;
        const reviewables = user.unseen_reviewable_count || 0;
        const count = unread + reviewables;
        if (count > 0) {
          if (this._shouldHighlightAvatar()) {
            this._addAvatarHighlight(contents);
          }
          contents.push(
            this.attach("link", {
              action: attrs.action,
              className: "badge-notification unread-notifications",
              rawLabel: count,
              omitSpan: true,
              title: "notifications.tooltip.regular",
              titleOptions: { count },
            })
          );
        }
      } else {
        const unreadNotifications = user.unread_notifications;
        if (!!unreadNotifications) {
          contents.push(
            this.attach("link", {
              action: attrs.action,
              className: "badge-notification unread-notifications",
              rawLabel: unreadNotifications,
              omitSpan: true,
              title: "notifications.tooltip.regular",
              titleOptions: { count: unreadNotifications },
            })
          );
        }

        const unreadHighPriority = user.unread_high_priority_notifications;
        if (!!unreadHighPriority) {
          if (this._shouldHighlightAvatar()) {
            this._addAvatarHighlight(contents);
          }

          // add the counter for the unread high priority
          contents.push(
            this.attach("link", {
              action: attrs.action,
              className:
                "badge-notification unread-high-priority-notifications",
              rawLabel: unreadHighPriority,
              omitSpan: true,
              title: "notifications.tooltip.high_priority",
              titleOptions: { count: unreadHighPriority },
            })
          );
        }
      }
    }
    return contents;
  },

  _shouldHighlightAvatar() {
    const attrs = this.attrs;
    const { user } = attrs;
    return (
      !user.read_first_notification &&
      !user.enforcedSecondFactor &&
      !attrs.active &&
      attrs.ringBackdrop
    );
  },

  _addAvatarHighlight(contents) {
    contents.push(h("span.ring"));
    contents.push(h("span.ring-backdrop-spotlight"));
    contents.push(
      h(
        "span.ring-backdrop",
        {},
        h("h1.ring-first-notification", {}, [
          h(
            "span",
            { className: "first-notification" },
            I18n.t("user.first_notification")
          ),
          h("span", { className: "read-later" }, [
            this.attach("link", {
              action: "readLater",
              className: "read-later-link",
              label: "user.skip_new_user_tips.read_later",
            }),
          ]),
          h("span", {}, [
            I18n.t("user.skip_new_user_tips.not_first_time"),
            " ",
            this.attach("link", {
              action: "skipNewUserTips",
              className: "skip-new-user-tips",
              label: "user.skip_new_user_tips.skip_link",
              title: "user.skip_new_user_tips.description",
            }),
          ]),
        ])
      )
    );
  },
});

createWidget(
  "user-dropdown",
  Object.assign(
    {
      tagName: "li.header-dropdown-toggle.current-user",

      buildId() {
        return "current-user";
      },

      html(attrs) {
        return h(
          "a.icon",
          {
            attributes: {
              "aria-haspopup": true,
              "aria-expanded": attrs.active,
              href: attrs.user.path,
              title: attrs.user.name || attrs.user.username,
              "data-auto-route": true,
            },
          },
          this.attach("header-notifications", attrs)
        );
      },
    },
    dropdown
  )
);

createWidget(
  "header-dropdown",
  Object.assign(
    {
      tagName: "li.header-dropdown-toggle",

      html(attrs) {
        const title = I18n.t(attrs.title);

        const body = [iconNode(attrs.icon)];
        if (attrs.contents) {
          body.push(attrs.contents.call(this));
        }

        return h(
          "a.icon.btn-flat",
          {
            attributes: {
              "aria-expanded": attrs.active,
              "aria-haspopup": true,
              href: attrs.href,
              "data-auto-route": true,
              title,
              "aria-label": title,
              id: attrs.iconId,
            },
          },
          body
        );
      },
    },
    dropdown
  )
);

createWidget("header-icons", {
  tagName: "ul.icons.d-header-icons",

  html(attrs) {
    if (this.siteSettings.login_required && !this.currentUser) {
      return [];
    }

    const icons = [];

    if (_extraHeaderIcons) {
      _extraHeaderIcons.forEach((icon) => {
        icons.push(this.attach(icon));
      });
    }

    const search = this.attach("header-dropdown", {
      title: "search.title",
      icon: "search",
      iconId: "search-button",
      action: "toggleSearchMenu",
      active: attrs.searchVisible,
      href: getURL("/search"),
      classNames: ["search-dropdown"],
    });

    icons.push(search);

    const hamburger = this.attach("header-dropdown", {
      title: "hamburger_menu",
      icon: "bars",
      iconId: "toggle-hamburger-menu",
      active: attrs.hamburgerVisible,
      action: "toggleHamburger",
      href: "",
      classNames: ["hamburger-dropdown"],

      contents() {
        let { currentUser } = this;
        if (
          currentUser?.reviewable_count &&
          !this.currentUser.redesigned_user_menu_enabled
        ) {
          return h(
            "div.badge-notification.reviewables",
            {
              attributes: {
                title: I18n.t("notifications.reviewable_items"),
              },
            },
            this.currentUser.reviewable_count
          );
        }
      },
    });

    if (
      !this.siteSettings.enable_experimental_sidebar_hamburger ||
      (this.siteSettings.enable_experimental_sidebar_hamburger &&
        !attrs.sidebarEnabled) ||
      this.site.mobileView
    ) {
      icons.push(hamburger);
    }

    if (attrs.user) {
      icons.push(
        this.attach("user-dropdown", {
          active: attrs.userVisible,
          action: "toggleUserMenu",
          ringBackdrop: attrs.ringBackdrop,
          user: attrs.user,
        })
      );
    }

    return icons;
  },
});

createWidget("header-buttons", {
  tagName: "span.header-buttons",

  html(attrs) {
    if (this.currentUser) {
      return;
    }

    const buttons = [];

    if (attrs.canSignUp && !attrs.topic) {
      buttons.push(
        this.attach("button", {
          label: "sign_up",
          className: "btn-primary btn-small sign-up-button",
          action: "showCreateAccount",
        })
      );
    }

    buttons.push(
      this.attach("button", {
        label: "log_in",
        className: "btn-primary btn-small login-button",
        action: "showLogin",
        icon: "user",
      })
    );
    return buttons;
  },
});

createWidget("header-cloak", {
  tagName: "div.header-cloak",
  html() {
    return "";
  },
  click() {},
  scheduleRerender() {},
});

let additionalPanels = [];
export function attachAdditionalPanel(name, toggle, transformAttrs) {
  additionalPanels.push({ name, toggle, transformAttrs });
}

createWidget("revamped-hamburger-menu-wrapper", {
  buildAttributes() {
    return { "data-click-outside": true };
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<Sidebar::HamburgerDropdown />`
      ),
    ];
  },

  clickOutside() {
    this.sendWidgetAction("toggleHamburger");
  },
});

createWidget("revamped-user-menu-wrapper", {
  buildAttributes() {
    return { "data-click-outside": true };
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<UserMenu::Menu />`
      ),
    ];
  },

  clickOutside() {
    this.sendWidgetAction("toggleUserMenu");
  },
});

export default createWidget("header", {
  tagName: "header.d-header.clearfix",
  buildKey: () => `header`,
  services: ["router", "search"],

  defaultState() {
    let states = {
      searchVisible: false,
      hamburgerVisible: false,
      userVisible: false,
      ringBackdrop: true,
      inTopicContext: false,
    };

    if (this.site.mobileView) {
      states.skipSearchContext = true;
    }

    return states;
  },

  html(attrs, state) {
    let inTopicRoute = false;

    if (this.state.inTopicContext) {
      inTopicRoute = this.router.currentRouteName.startsWith("topic.");
    }

    let contents = () => {
      const headerIcons = this.attach("header-icons", {
        hamburgerVisible: state.hamburgerVisible,
        userVisible: state.userVisible,
        searchVisible: state.searchVisible,
        ringBackdrop: state.ringBackdrop,
        flagCount: attrs.flagCount,
        user: this.currentUser,
        sidebarEnabled: attrs.sidebarEnabled,
      });

      if (attrs.onlyIcons) {
        return headerIcons;
      }

      const panels = [this.attach("header-buttons", attrs), headerIcons];

      if (state.searchVisible) {
        panels.push(
          this.attach("search-menu", {
            inTopicContext: state.inTopicContext && inTopicRoute,
          })
        );
      } else if (state.hamburgerVisible) {
        if (this.siteSettings.enable_experimental_sidebar_hamburger) {
          if (!attrs.sidebarEnabled) {
            panels.push(this.attach("revamped-hamburger-menu-wrapper", {}));
          }
        } else {
          panels.push(this.attach("hamburger-menu"));
        }
      } else if (state.userVisible) {
        if (this.currentUser.redesigned_user_menu_enabled) {
          panels.push(this.attach("revamped-user-menu-wrapper", {}));
        } else {
          panels.push(this.attach("user-menu"));
        }
      }

      additionalPanels.map((panel) => {
        if (this.state[panel.toggle]) {
          panels.push(
            this.attach(
              panel.name,
              panel.transformAttrs.call(this, attrs, state)
            )
          );
        }
      });

      if (this.site.mobileView) {
        panels.push(this.attach("header-cloak"));
      }

      return panels;
    };

    const contentsAttrs = {
      contents,
      minimized: !!attrs.topic,
    };

    return h(
      "div.wrap",
      this.attach("header-contents", Object.assign({}, attrs, contentsAttrs))
    );
  },

  updateHighlight() {
    if (!this.state.searchVisible) {
      this.search.set("highlightTerm", "");
    }
  },

  closeAll() {
    this.state.userVisible = false;
    this.state.hamburgerVisible = false;
    this.state.searchVisible = false;
    this.toggleBodyScrolling(false);
  },

  linkClickedEvent(attrs) {
    let searchContextEnabled = false;
    if (attrs) {
      searchContextEnabled = attrs.searchContextEnabled;

      const { searchLogId, searchResultId, searchResultType } = attrs;
      if (searchLogId && searchResultId && searchResultType) {
        logSearchLinkClick({ searchLogId, searchResultId, searchResultType });
      }
    }

    if (!searchContextEnabled) {
      this.closeAll();
    }

    this.updateHighlight();
  },

  toggleSearchMenu() {
    if (this.site.mobileView) {
      const context = this.search.searchContext;
      let params = "";

      if (context) {
        params = `?context=${context.type}&context_id=${context.id}&skip_context=${this.state.skipSearchContext}`;
      }

      if (this.router.currentRouteName === "full-page-search") {
        scrollTop();
        $(".full-page-search").focus();
        return false;
      } else {
        return DiscourseURL.routeTo("/search" + params);
      }
    }

    this.state.searchVisible = !this.state.searchVisible;
    this.updateHighlight();

    if (this.state.searchVisible) {
      this.focusSearchInput();
    } else {
      this.state.inTopicContext = false;
    }
  },

  toggleUserMenu() {
    if (this.currentUser.get("read_first_notification")) {
      this.state.ringBackdrop = false;
    }

    this.state.userVisible = !this.state.userVisible;
    this.toggleBodyScrolling(this.state.userVisible);

    // auto focus on first button in dropdown
    schedule("afterRender", () =>
      document.querySelector(".user-menu button")?.focus()
    );
  },

  toggleHamburger() {
    if (
      this.siteSettings.enable_experimental_sidebar_hamburger &&
      this.attrs.sidebarEnabled
    ) {
      this.sendWidgetAction("toggleSidebar");
    } else {
      this.state.hamburgerVisible = !this.state.hamburgerVisible;
      this.toggleBodyScrolling(this.state.hamburgerVisible);

      // auto focus on first link in dropdown
      schedule("afterRender", () => {
        document.querySelector(".hamburger-panel .menu-links a")?.focus();
      });
    }
  },

  toggleBodyScrolling(bool) {
    if (!this.site.mobileView) {
      return;
    }
    if (bool) {
      document.body.addEventListener("touchmove", this.preventDefault, {
        passive: false,
      });
    } else {
      document.body.removeEventListener("touchmove", this.preventDefault, {
        passive: false,
      });
    }
  },

  preventDefault(e) {
    // prevent all scrolling on menu panels, except on overflow
    const height = window.innerHeight ? window.innerHeight : $(window).height();
    if (
      !$(e.target).parents(".menu-panel").length ||
      $(".menu-panel .panel-body-contents").height() <= height
    ) {
      e.preventDefault();
    }
  },

  togglePageSearch() {
    const { state } = this;
    state.inTopicContext = false;

    let showSearch = this.router.currentRouteName.startsWith("topic.");

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch) {
      const controller = this.register.lookup("controller:topic");
      const total = controller.get("model.postStream.stream.length") || 0;
      const chunkSize = controller.get("model.chunk_size") || 0;

      showSearch =
        total > chunkSize &&
        $(".topic-post .cooked, .small-action:not(.time-gap)").length < total;
    }

    if (state.searchVisible) {
      this.toggleSearchMenu();
      return showSearch;
    }

    if (showSearch) {
      state.inTopicContext = true;
      this.toggleSearchMenu();
      return false;
    }

    return true;
  },

  domClean() {
    const { state } = this;

    if (state.searchVisible || state.hamburgerVisible || state.userVisible) {
      this.closeAll();
    }
  },

  headerDismissFirstNotificationMask() {
    // Dismiss notifications
    if (document.body.classList.contains("unread-first-notification")) {
      document.body.classList.remove("unread-first-notification");
    }
    this.store
      .findStale(
        "notification",
        {
          recent: true,
          silent: this.get("currentUser.enforcedSecondFactor"),
          limit: 5,
        },
        { cacheKey: "recent-notifications" }
      )
      .refresh();
    // Update UI
    this.state.ringBackdrop = false;
    this.scheduleRerender();
  },

  readLater() {
    this.headerDismissFirstNotificationMask();
  },

  skipNewUserTips() {
    this.headerDismissFirstNotificationMask();
    ajax(userPath(this.currentUser.username_lower), {
      type: "PUT",
      data: {
        skip_new_user_tips: true,
      },
    }).then(() => {
      this.currentUser.set("skip_new_user_tips", true);
    });
  },

  headerKeyboardTrigger(msg) {
    switch (msg.type) {
      case "search":
        this.toggleSearchMenu();
        break;
      case "user":
        this.toggleUserMenu();
        break;
      case "hamburger":
        this.toggleHamburger();
        break;
      case "page-search":
        if (!this.togglePageSearch()) {
          msg.event.preventDefault();
          msg.event.stopPropagation();
        }
        break;
    }
  },

  focusSearchInput() {
    if (this.state.searchVisible) {
      schedule("afterRender", () => {
        const searchInput = document.querySelector("#search-term");
        searchInput.focus();
        searchInput.select();
      });
    }
  },

  setTopicContext() {
    this.state.inTopicContext = true;
    this.focusSearchInput();
  },

  clearContext() {
    this.state.inTopicContext = false;
    this.focusSearchInput();
  },
});
