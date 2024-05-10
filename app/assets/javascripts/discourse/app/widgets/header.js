import { schedule } from "@ember/runloop";
import { hbs } from "ember-cli-htmlbars";
import $ from "jquery";
import { h } from "virtual-dom";
import { headerButtonsDAG } from "discourse/components/header";
import { headerIconsDAG } from "discourse/components/header/icons";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import scrollLock from "discourse/lib/scroll-lock";
import { isDocumentRTL } from "discourse/lib/text-direction";
import DiscourseURL from "discourse/lib/url";
import { scrollTop } from "discourse/mixins/scroll-top";
import { avatarImg } from "discourse/widgets/post";
import RenderGlimmer, {
  registerWidgetShim,
} from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import { isTesting } from "discourse-common/config/environment";
import getURL from "discourse-common/lib/get-url";
import { iconNode } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";

const SEARCH_BUTTON_ID = "search-button";

let _extraHeaderIcons;
clearExtraHeaderIcons();

let _extraHeaderButtons;
clearExtraHeaderButtons();

export function clearExtraHeaderIcons() {
  _extraHeaderIcons = headerIconsDAG();
}

export function clearExtraHeaderButtons() {
  _extraHeaderButtons = headerButtonsDAG();
}

export const dropdown = {
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
  services: ["user-tips"],

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
          { alt: "user.avatar.header_title" },
          addExtraUserClasses(user, avatarAttrs)
        )
      ),
    ];

    if (this.currentUser && this._shouldHighlightAvatar()) {
      contents.push(this.attach("header-user-tip-shim"));
    }

    if (this.currentUser.status) {
      contents.push(this.attach("user-status-bubble", this.currentUser.status));
    }

    if (user.isInDoNotDisturb()) {
      contents.push(
        h("div.do-not-disturb-background", iconNode("discourse-dnd"))
      );
    } else {
      if (user.new_personal_messages_notifications_count) {
        contents.push(
          this.attach("link", {
            action: attrs.action,
            className: "badge-notification with-icon new-pms",
            icon: "envelope",
            omitSpan: true,
            title: "notifications.tooltip.new_message_notification",
            titleOptions: {
              count: user.new_personal_messages_notifications_count,
            },
            attributes: {
              "aria-label": I18n.t(
                "notifications.tooltip.new_message_notification",
                {
                  count: user.new_personal_messages_notifications_count,
                }
              ),
            },
          })
        );
      } else if (user.unseen_reviewable_count) {
        contents.push(
          this.attach("link", {
            action: attrs.action,
            className: "badge-notification with-icon new-reviewables",
            icon: "flag",
            omitSpan: true,
            title: "notifications.tooltip.new_reviewable",
            titleOptions: { count: user.unseen_reviewable_count },
            attributes: {
              "aria-label": I18n.t("notifications.tooltip.new_reviewable", {
                count: user.unseen_reviewable_count,
              }),
            },
          })
        );
      } else if (user.all_unread_notifications_count) {
        contents.push(
          this.attach("link", {
            action: attrs.action,
            className: "badge-notification unread-notifications",
            rawLabel: user.all_unread_notifications_count,
            omitSpan: true,
            title: "notifications.tooltip.regular",
            titleOptions: { count: user.all_unread_notifications_count },
            attributes: {
              "aria-label": I18n.t("user.notifications"),
            },
          })
        );
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
      !attrs.active
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
          "button.icon.btn.no-text.btn-flat",
          {
            attributes: {
              "aria-haspopup": true,
              "aria-expanded": attrs.active,
              "aria-label": I18n.t("user.account_possessive", {
                name: attrs.user.name || attrs.user.username,
              }),
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
          "button.icon.btn.no-text.btn-flat",
          {
            attributes: {
              "aria-expanded": attrs.active,
              "aria-haspopup": true,
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
  services: ["search"],
  tagName: "ul.icons.d-header-icons",

  init() {
    registerWidgetShim("extra-icon", "span.wrapper", hbs`<@data.component />`);
  },

  html(attrs) {
    if (this.siteSettings.login_required && !this.currentUser) {
      return [];
    }

    const icons = [];

    const resolvedIcons = _extraHeaderIcons.resolve();

    resolvedIcons.forEach((icon) => {
      if (icon.key === "search") {
        icons.push(
          this.attach("header-dropdown", {
            title: "search.title",
            icon: "search",
            iconId: SEARCH_BUTTON_ID,
            action: "toggleSearchMenu",
            active: this.search.visible,
            href: getURL("/search"),
            classNames: ["search-dropdown"],
          })
        );
      } else if (icon.key === "user-menu" && attrs.user) {
        icons.push(
          this.attach("user-dropdown", {
            active: attrs.userVisible,
            action: "toggleUserMenu",
            user: attrs.user,
          })
        );
      } else if (
        icon.key === "hamburger" &&
        (!attrs.sidebarEnabled || this.site.mobileView)
      ) {
        icons.push(
          this.attach("header-dropdown", {
            title: "hamburger_menu",
            icon: "bars",
            iconId: "toggle-hamburger-menu",
            active: attrs.hamburgerVisible,
            action: "toggleHamburger",
            href: "",
            classNames: ["hamburger-dropdown"],
          })
        );
      } else {
        icons.push(this.attach("extra-icon", { component: icon.value }));
      }
    });

    return icons;
  },
});

createWidget("header-buttons", {
  tagName: "span.auth-buttons",

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

createWidget("hamburger-dropdown-wrapper", {
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

  click(event) {
    if (
      event.target.closest(".sidebar-section-header-button") ||
      event.target.closest(".sidebar-section-link")
    ) {
      this.sendWidgetAction("toggleHamburger");
    }
  },

  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition = isDocumentRTL() ? "340px" : "-340px";
      panel
        .animate([{ transform: `translate3d(${finishPosition}, 0, 0)` }], {
          duration: 200,
          fill: "forwards",
          easing: "ease-in",
        })
        .finished.then(() => {
          if (isTesting()) {
            this.sendWidgetAction("toggleHamburger");
          } else {
            discourseLater(() => this.sendWidgetAction("toggleHamburger"));
          }
        });
      headerCloak.animate([{ opacity: 0 }], {
        duration: 200,
        fill: "forwards",
        easing: "ease-in",
      });
    } else {
      this.sendWidgetAction("toggleHamburger");
    }
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
        hbs`<UserMenu::Menu @closeUserMenu={{@data.closeUserMenu}} />`,
        {
          closeUserMenu: this.closeUserMenu.bind(this),
        }
      ),
    ];
  },

  closeUserMenu() {
    this.sendWidgetAction("toggleUserMenu");
  },

  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition = isDocumentRTL() ? "-340px" : "340px";
      panel
        .animate([{ transform: `translate3d(${finishPosition}, 0, 0)` }], {
          duration: 200,
          fill: "forwards",
          easing: "ease-in",
        })
        .finished.then(() => {
          if (isTesting) {
            this.closeUserMenu();
          } else {
            discourseLater(() => this.closeUserMenu());
          }
        });
      headerCloak.animate([{ opacity: 0 }], {
        duration: 200,
        fill: "forwards",
        easing: "ease-in",
      });
    } else {
      this.closeUserMenu();
    }
  },
});

createWidget("search-menu-wrapper", {
  services: ["search"],
  buildAttributes() {
    return { "aria-live": "polite" };
  },

  buildClasses() {
    return ["search-menu"];
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<SearchMenuPanel @closeSearchMenu={{@data.closeSearchMenu}} />`,
        {
          closeSearchMenu: this.closeSearchMenu.bind(this),
        }
      ),
    ];
  },

  closeSearchMenu() {
    this.sendWidgetAction("toggleSearchMenu");
    document.getElementById(SEARCH_BUTTON_ID)?.focus();
  },

  clickOutside() {
    this.closeSearchMenu();
  },
});

export default createWidget("header", {
  tagName: "header.d-header",
  buildKey: () => `header`,
  services: ["router", "search"],

  init() {
    registerWidgetShim(
      "extra-button",
      "span.wrapper",
      hbs`<@data.component />`
    );
  },

  defaultState() {
    let states = {
      searchVisible: false,
      hamburgerVisible: false,
      userVisible: false,
      inTopicContext: false,
    };

    if (this.site.mobileView) {
      states.skipSearchContext = true;
    }

    return states;
  },

  html(attrs, state) {
    let inTopicRoute = false;
    if (this.search.inTopicContext) {
      inTopicRoute = this.router.currentRouteName.startsWith("topic.");
    }

    let contents = () => {
      const headerIcons = this.attach("header-icons", {
        hamburgerVisible: state.hamburgerVisible,
        userVisible: state.userVisible,
        searchVisible: this.search.visible,
        flagCount: attrs.flagCount,
        user: this.currentUser,
        sidebarEnabled: attrs.sidebarEnabled,
      });

      if (attrs.onlyIcons) {
        return headerIcons;
      }

      const buttons = [];
      const resolvedButtons = _extraHeaderButtons.resolve();
      resolvedButtons.forEach((button) => {
        if (button.key === "auth") {
          buttons.push(this.attach("header-buttons", attrs));
        }
        buttons.push(this.attach("extra-button", { component: button.value }));
      });

      const panels = [];
      panels.push(h("span.header-buttons", buttons), headerIcons);

      if (this.search.visible) {
        this.search.inTopicContext = this.search.inTopicContext && inTopicRoute;
        panels.push(this.attach("search-menu-wrapper"));
      } else if (state.hamburgerVisible) {
        panels.push(this.attach("hamburger-dropdown-wrapper", {}));
      } else if (state.userVisible) {
        panels.push(this.attach("revamped-user-menu-wrapper", {}));
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

      if (this.site.mobileView || this.site.narrowDesktopView) {
        panels.push(this.attach("header-cloak"));
      }

      return panels;
    };

    const contentsAttrs = {
      contents,
      minimized: !!attrs.topic,
    };

    return [
      h(
        "div.wrap",
        this.attach("header-contents", { ...attrs, ...contentsAttrs })
      ),
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`
          <PluginOutlet
            @name="after-header"
            @outletArgs={{hash minimized=@data.minimized}}
          />
        `,
        { minimized: !!attrs.topic }
      ),
    ];
  },

  updateHighlight() {
    if (!this.search.visible) {
      this.search.highlightTerm = "";
    }
  },

  closeAll() {
    this.state.userVisible = false;
    this.state.hamburgerVisible = false;
    this.search.visible = false;
    this.toggleBodyScrolling(false);
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

    this.search.visible = !this.search.visible;
    this.updateHighlight();

    if (!this.search.searchVisible) {
      this.search.inTopicContext = false;
    }
  },

  toggleUserMenu() {
    this.state.userVisible = !this.state.userVisible;
    this.toggleBodyScrolling(this.state.userVisible);

    // auto focus on first button in dropdown
    schedule("afterRender", () =>
      document.querySelector(".user-menu button")?.focus()
    );
  },

  toggleHamburger() {
    if (this.attrs.sidebarEnabled && !this.site.narrowDesktopView) {
      this.sendWidgetAction("toggleSidebar");
    } else {
      this.state.hamburgerVisible = !this.state.hamburgerVisible;
      this.toggleBodyScrolling(this.state.hamburgerVisible);
      schedule("afterRender", () => {
        // Remove focus from hamburger toggle button
        document.querySelector("#toggle-hamburger-menu")?.blur();
      });
    }
  },

  toggleBodyScrolling(bool) {
    if (this.site.mobileView) {
      scrollLock(bool);
    }
  },

  togglePageSearch() {
    this.search.inTopicContext = false;
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

    if (this.search.visible) {
      this.toggleSearchMenu();
      return showSearch;
    }

    if (showSearch) {
      this.search.inTopicContext = true;
      this.toggleSearchMenu();
      return false;
    }

    return true;
  },

  domClean() {
    const { state } = this;

    if (this.search.visible || state.hamburgerVisible || state.userVisible) {
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
        if (!this.togglePageSearch()) {
          msg.event.preventDefault();
          msg.event.stopPropagation();
        }
        break;
    }
  },
});
