import DiscourseURL, { userPath } from "discourse/lib/url";
import I18n from "I18n";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import { applySearchAutocomplete } from "discourse/lib/search";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { get } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { schedule } from "@ember/runloop";
import { scrollTop } from "discourse/mixins/scroll-top";
import { wantsNewWindow } from "discourse/lib/intercept-click";

const _extraHeaderIcons = [];

export function addToHeaderIcons(icon) {
  _extraHeaderIcons.push(icon);
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

    if (user.isInDoNotDisturb()) {
      contents.push(h("div.do-not-disturb-background", iconNode("moon")));
    } else {
      const unreadNotifications = user.get("unread_notifications");
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

      const unreadHighPriority = user.get("unread_high_priority_notifications");
      if (!!unreadHighPriority) {
        // highlight the avatar if the first ever PM is not read
        if (
          !user.get("read_first_notification") &&
          !user.get("enforcedSecondFactor")
        ) {
          if (!attrs.active && attrs.ringBackdrop) {
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
          }
        }

        // add the counter for the unread high priority
        contents.push(
          this.attach("link", {
            action: attrs.action,
            className: "badge-notification unread-high-priority-notifications",
            rawLabel: unreadHighPriority,
            omitSpan: true,
            title: "notifications.tooltip.high_priority",
            titleOptions: { count: unreadHighPriority },
          })
        );
      }
    }
    return contents;
  },
});

createWidget(
  "user-dropdown",
  jQuery.extend(
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
  jQuery.extend(
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

  buildAttributes() {
    return { role: "navigation" };
  },

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
        if (currentUser && currentUser.reviewable_count) {
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

    icons.push(hamburger);

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

const forceContextEnabled = ["category", "user", "private_messages", "tag"];

let additionalPanels = [];
export function attachAdditionalPanel(name, toggle, transformAttrs) {
  additionalPanels.push({ name, toggle, transformAttrs });
}

export default createWidget("header", {
  tagName: "header.d-header.clearfix",
  buildKey: () => `header`,

  defaultState() {
    let states = {
      searchVisible: false,
      hamburgerVisible: false,
      userVisible: false,
      ringBackdrop: true,
    };

    if (this.site.mobileView) {
      states.skipSearchContext = true;
    }

    return states;
  },

  html(attrs, state) {
    let contents = () => {
      const headerIcons = this.attach("header-icons", {
        hamburgerVisible: state.hamburgerVisible,
        userVisible: state.userVisible,
        searchVisible: state.searchVisible,
        ringBackdrop: state.ringBackdrop,
        flagCount: attrs.flagCount,
        user: this.currentUser,
      });

      if (attrs.onlyIcons) {
        return headerIcons;
      }

      const panels = [this.attach("header-buttons", attrs), headerIcons];

      if (state.searchVisible) {
        const contextType = this.searchContextType();

        if (state.searchContextType !== contextType) {
          state.contextEnabled = undefined;
          state.searchContextType = contextType;
        }

        if (state.contextEnabled === undefined) {
          if (forceContextEnabled.includes(contextType)) {
            state.contextEnabled = true;
          }
        }

        panels.push(
          this.attach("search-menu", { contextEnabled: state.contextEnabled })
        );
      } else if (state.hamburgerVisible) {
        panels.push(this.attach("hamburger-menu"));
      } else if (state.userVisible) {
        panels.push(this.attach("user-menu"));
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

    let contentsAttrs = { contents, minimized: !!attrs.topic };
    return h(
      "div.wrap",
      this.attach("header-contents", $.extend({}, attrs, contentsAttrs))
    );
  },

  updateHighlight() {
    if (!this.state.searchVisible) {
      const service = this.register.lookup("search-service:main");
      service.set("highlightTerm", "");
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
        ajax("/search/click", {
          type: "POST",
          data: {
            search_log_id: searchLogId,
            search_result_id: searchResultId,
            search_result_type: searchResultType,
          },
        });
      }
    }

    if (!searchContextEnabled) {
      this.closeAll();
    }

    this.updateHighlight();
  },

  toggleSearchMenu() {
    if (this.site.mobileView) {
      const searchService = this.register.lookup("search-service:main");
      const context = searchService.get("searchContext");
      let params = "";

      if (context) {
        params = `?context=${context.type}&context_id=${context.id}&skip_context=${this.state.skipSearchContext}`;
      }

      const currentPath = this.register
        .lookup("service:router")
        .get("_router.currentPath");

      if (currentPath === "full-page-search") {
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
      schedule("afterRender", () => {
        const $searchInput = $("#search-term");
        $searchInput.focus().select();

        applySearchAutocomplete(
          $searchInput,
          this.siteSettings,
          this.appEvents,
          {
            appendSelector: ".menu-panel",
          }
        );
      });
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
    this.state.hamburgerVisible = !this.state.hamburgerVisible;
    this.toggleBodyScrolling(this.state.hamburgerVisible);

    // auto focus on first link in dropdown
    schedule("afterRender", () => {
      document.querySelector(".hamburger-panel .menu-links a")?.focus();
    });
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
    // prevent all scrollin on menu panels, except on overflow
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

    state.contextEnabled = false;

    const currentPath = this.register
      .lookup("service:router")
      .get("_router.currentPath");
    const blocklist = [/^discovery\.categories/];
    const allowlist = [/^topic\./];
    const check = function (regex) {
      return !!currentPath.match(regex);
    };
    let showSearch = allowlist.any(check) && !blocklist.any(check);

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch && currentPath.match(/^topic\./)) {
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
      state.contextEnabled = true;
      this.toggleSearchMenu();
      return false;
    }

    return true;
  },

  searchMenuContextChanged(value) {
    this.state.contextType = this.register
      .lookup("search-service:main")
      .get("contextType");
    this.state.contextEnabled = value;
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
        let contextType = this.searchContextType();
        if (contextType === "topic") {
          this.state.searchContextType = contextType;
        }
        if (!this.togglePageSearch()) {
          msg.event.preventDefault();
          msg.event.stopPropagation();
        }
        break;
    }
  },

  searchContextType() {
    const service = this.register.lookup("search-service:main");
    if (service) {
      const ctx = service.get("searchContext");
      if (ctx) {
        return get(ctx, "type");
      }
    }
  },
});
