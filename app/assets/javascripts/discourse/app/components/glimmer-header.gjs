import { schedule } from "@ember/runloop";
import { hbs } from "ember-cli-htmlbars";
import $ from "jquery";
import { h } from "virtual-dom";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import scrollLock from "discourse/lib/scroll-lock";
import { logSearchLinkClick } from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";
import { scrollTop } from "discourse/mixins/scroll-top";
import { avatarImg } from "discourse/widgets/post";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import { isTesting } from "discourse-common/config/environment";
import getURL from "discourse-common/lib/get-url";
import { iconNode } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";

const SEARCH_BUTTON_ID = "search-button";

let _extraHeaderIcons = [];

export function addToHeaderIcons(icon) {
  _extraHeaderIcons.push(icon);
}

export function clearExtraHeaderIcons() {
  _extraHeaderIcons = [];
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

export default createWidget("header", {
  tagName: "header.d-header",
  buildKey: () => `header`,
  services: ["router", "search"],

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
    if (this.state.inTopicContext || this.search.inTopicContext) {
      inTopicRoute = this.router.currentRouteName.startsWith("topic.");
    }

    let contents = () => {
      const headerIcons = this.attach("header-icons", {
        hamburgerVisible: state.hamburgerVisible,
        userVisible: state.userVisible,
        searchVisible: state.searchVisible || this.search.visible,
        flagCount: attrs.flagCount,
        user: this.currentUser,
        sidebarEnabled: attrs.sidebarEnabled,
      });

      if (attrs.onlyIcons) {
        return headerIcons;
      }

      const panels = [this.attach("header-buttons", attrs), headerIcons];

      if (state.searchVisible || this.search.visible) {
        if (this.siteSettings.experimental_search_menu) {
          this.search.inTopicContext =
            this.search.inTopicContext && inTopicRoute;
          panels.push(this.attach("glimmer-search-menu-wrapper"));
        } else {
          panels.push(
            this.attach("search-menu", {
              inTopicContext: state.inTopicContext && inTopicRoute,
            })
          );
        }
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

    return h(
      "div.wrap",
      this.attach("header-contents", { ...attrs, ...contentsAttrs })
    );
  },

  updateHighlight() {
    if (!this.state.searchVisible || !this.search.visible) {
      this.search.highlightTerm = "";
    }
  },

  closeAll() {
    this.state.userVisible = false;
    this.state.hamburgerVisible = false;
    this.state.searchVisible = false;
    this.search.visible = false;
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
    this.search.visible = !this.search.visible;
    this.updateHighlight();

    if (this.state.searchVisible) {
      // only used by the widget search-menu
      this.focusSearchInput();
    } else {
      this.state.inTopicContext = false;
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
    if (!this.site.mobileView) {
      return;
    }
    scrollLock(bool);
  },

  togglePageSearch() {
    const { state } = this;
    this.search.inTopicContext = false;
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

    if (state.searchVisible || this.search.visible) {
      this.toggleSearchMenu();
      return showSearch;
    }

    if (showSearch) {
      state.inTopicContext = true;
      this.search.inTopicContext = true;
      this.toggleSearchMenu();
      return false;
    }

    return true;
  },

  domClean() {
    const { state } = this;

    if (
      state.searchVisible ||
      this.search.visible ||
      state.hamburgerVisible ||
      state.userVisible
    ) {
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

  // only used by the widget search-menu
  focusSearchInput() {
    if (
      this.state.searchVisible &&
      !this.siteSettings.experimental_search_menu
    ) {
      schedule("afterRender", () => {
        const searchInput = document.querySelector("#search-term");
        searchInput.focus();
        searchInput.select();
      });
    }
  },

  // only used by the widget search-menu
  setTopicContext() {
    this.state.inTopicContext = true;
    this.focusSearchInput();
  },

  // only used by the widget search-menu
  clearContext() {
    this.state.inTopicContext = false;
    this.focusSearchInput();
  },
});

let additionalPanels = [];
export function attachAdditionalPanel(name, toggle, transformAttrs) {
  additionalPanels.push({ name, toggle, transformAttrs });
}
