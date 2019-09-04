import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { avatarImg } from "discourse/widgets/post";
import DiscourseURL from "discourse/lib/url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { applySearchAutocomplete } from "discourse/lib/search";
import { ajax } from "discourse/lib/ajax";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { scrollTop } from "discourse/mixins/scroll-top";
import { h } from "virtual-dom";

const dropdown = {
  buildClasses(attrs) {
    if (attrs.active) {
      return "active";
    }
  },

  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    if (!this.attrs.active) {
      this.sendWidgetAction(this.attrs.action);
    }
  }
};

createWidget("header-notifications", {
  settings: {
    avatarSize: "medium"
  },

  html(attrs) {
    const { user } = attrs;

    let avatarAttrs = {
      template: user.get("avatar_template"),
      username: user.get("username")
    };

    if (this.siteSettings.enable_names) {
      avatarAttrs.name = user.get("name");
    }

    const contents = [
      avatarImg(
        this.settings.avatarSize,
        addExtraUserClasses(user, avatarAttrs)
      )
    ];

    const unreadNotifications = user.get("unread_notifications");
    if (!!unreadNotifications) {
      contents.push(
        this.attach("link", {
          action: attrs.action,
          className: "badge-notification unread-notifications",
          rawLabel: unreadNotifications,
          omitSpan: true,
          title: "notifications.tooltip.regular",
          titleOptions: { count: unreadNotifications }
        })
      );
    }

    const unreadPMs = user.get("unread_private_messages");
    if (!!unreadPMs) {
      if (
        !user.get("read_first_notification") &&
        !user.get("enforcedSecondFactor")
      ) {
        contents.push(h("span.ring"));
        if (!attrs.active && attrs.ringBackdrop) {
          contents.push(h("span.ring-backdrop-spotlight"));
          contents.push(
            h(
              "span.ring-backdrop",
              {},
              h(
                "h1.ring-first-notification",
                {},
                I18n.t("user.first_notification")
              )
            )
          );
        }
      }

      contents.push(
        this.attach("link", {
          action: attrs.action,
          className: "badge-notification unread-private-messages",
          rawLabel: unreadPMs,
          omitSpan: true,
          title: "notifications.tooltip.message",
          titleOptions: { count: unreadPMs }
        })
      );
    }

    return contents;
  }
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
              href: attrs.user.get("path"),
              "data-auto-route": true
            }
          },
          this.attach("header-notifications", attrs)
        );
      }
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
              href: attrs.href,
              "data-auto-route": true,
              title,
              "aria-label": title,
              id: attrs.iconId
            }
          },
          body
        );
      }
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

    const hamburger = this.attach("header-dropdown", {
      title: "hamburger_menu",
      icon: "bars",
      iconId: "toggle-hamburger-menu",
      active: attrs.hamburgerVisible,
      action: "toggleHamburger",
      href: "",
      contents() {
        let { currentUser } = this;
        if (currentUser && currentUser.reviewable_count) {
          return h(
            "div.badge-notification.reviewables",
            {
              attributes: {
                title: I18n.t("notifications.reviewable_items")
              }
            },
            this.currentUser.reviewable_count
          );
        }
      }
    });

    const search = this.attach("header-dropdown", {
      title: "search.title",
      icon: "search",
      iconId: "search-button",
      action: "toggleSearchMenu",
      active: attrs.searchVisible,
      href: Discourse.getURL("/search")
    });

    const icons = [search, hamburger];
    if (attrs.user) {
      icons.push(
        this.attach("user-dropdown", {
          active: attrs.userVisible,
          action: "toggleUserMenu",
          ringBackdrop: attrs.ringBackdrop,
          user: attrs.user
        })
      );
    }

    return icons;
  }
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
          action: "showCreateAccount"
        })
      );
    }

    buttons.push(
      this.attach("button", {
        label: "log_in",
        className: "btn-primary btn-small login-button",
        action: "showLogin",
        icon: "user"
      })
    );
    return buttons;
  }
});

createWidget("header-cloak", {
  tagName: "div.header-cloak",
  html() {
    return "";
  },
  click() {},
  scheduleRerender() {}
});

const forceContextEnabled = ["category", "user", "private_messages"];

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
      ringBackdrop: true
    };

    if (this.site.mobileView) {
      states.skipSearchContext = true;
    }

    return states;
  },

  html(attrs, state) {
    let contents = () => {
      const panels = [
        this.attach("header-buttons", attrs),
        this.attach("header-icons", {
          hamburgerVisible: state.hamburgerVisible,
          userVisible: state.userVisible,
          searchVisible: state.searchVisible,
          ringBackdrop: state.ringBackdrop,
          flagCount: attrs.flagCount,
          user: this.currentUser
        })
      ];

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

      additionalPanels.map(panel => {
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
            search_result_type: searchResultType
          }
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
      var params = "";

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
      Ember.run.schedule("afterRender", () => {
        const $searchInput = $("#search-term");
        $searchInput.focus().select();

        applySearchAutocomplete(
          $searchInput,
          this.siteSettings,
          this.appEvents,
          {
            appendSelector: ".menu-panel"
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
  },

  toggleHamburger() {
    this.state.hamburgerVisible = !this.state.hamburgerVisible;
    this.toggleBodyScrolling(this.state.hamburgerVisible);
  },

  toggleBodyScrolling(bool) {
    if (!this.site.mobileView) return;
    if (bool) {
      document.body.addEventListener("touchmove", this.preventDefault, {
        passive: false
      });
    } else {
      document.body.removeEventListener("touchmove", this.preventDefault, {
        passive: false
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
    const blacklist = [/^discovery\.categories/];
    const whitelist = [/^topic\./];
    const check = function(regex) {
      return !!currentPath.match(regex);
    };
    let showSearch = whitelist.any(check) && !blacklist.any(check);

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
        return Ember.get(ctx, "type");
      }
    }
  }
});
