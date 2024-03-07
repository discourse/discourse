import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { and, not, or } from "truth-helpers";
import scrollLock from "discourse/lib/scroll-lock";
import DiscourseURL from "discourse/lib/url";
import { scrollTop } from "discourse/mixins/scroll-top";
import AuthButtons from "./glimmer-header/auth-buttons";
import Contents from "./glimmer-header/contents";
import HamburgerDropdownWrapper from "./glimmer-header/hamburger-dropdown-wrapper";
import Icons from "./glimmer-header/icons";
import SearchMenuWrapper from "./glimmer-header/search-menu-wrapper";
import UserMenuWrapper from "./glimmer-header/user-menu-wrapper";
import PluginOutlet from "./plugin-outlet";

const SEARCH_BUTTON_ID = "search-button";

export default class GlimmerHeader extends Component {
  @service router;
  @service search;
  @service currentUser;
  @service site;
  @service appEvents;
  @service header;

  @tracked skipSearchContext = this.site.mobileView;
  @tracked panelElement;

  appEventsListeners = modifier(() => {
    this.appEvents.on(
      "header:keyboard-trigger",
      this,
      this.headerKeyboardTrigger
    );
    return () => {
      this.appEvents.off(
        "header:keyboard-trigger",
        this,
        this.headerKeyboardTrigger
      );
    };
  });

  @action
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
  }

  @action
  toggleSearchMenu() {
    if (this.site.mobileView) {
      const context = this.search.searchContext;
      let params = "";
      if (context) {
        params = `?context=${context.type}&context_id=${context.id}&skip_context=${this.skipSearchContext}`;
      }

      if (this.router.currentRouteName === "full-page-search") {
        scrollTop();
        document.querySelector(".full-page-search").focus();
        return false;
      } else {
        return DiscourseURL.routeTo("/search" + params);
      }
    }

    this.search.visible = !this.search.visible;
    if (!this.search.visible) {
      this.search.highlightTerm = "";
      this.search.inTopicContext = false;
      document.getElementById(SEARCH_BUTTON_ID)?.focus();
    }
  }

  @action
  togglePageSearch() {
    this.search.inTopicContext = false;

    let showSearch = this.router.currentRouteName.startsWith("topic.");
    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch) {
      const container = getOwner(this);
      const topic = container.lookup("controller:topic");
      const total = topic.get("model.postStream.stream.length") || 0;
      const chunkSize = topic.get("model.chunk_size") || 0;
      showSearch =
        total > chunkSize &&
        document.querySelectorAll(
          ".topic-post .cooked, .small-action:not(.time-gap)"
        )?.length < total;
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
  }

  @action
  toggleUserMenu() {
    this.header.userVisible = !this.header.userVisible;
    this.toggleBodyScrolling(this.header.userVisible);
    this.args.animateMenu();
  }

  @action
  toggleHamburger() {
    if (this.args.sidebarEnabled && !this.site.narrowDesktopView) {
      this.args.toggleSidebar();
      this.args.animateMenu();
    } else {
      this.header.hamburgerVisible = !this.header.hamburgerVisible;
      this.toggleBodyScrolling(this.header.hamburgerVisible);
      this.args.animateMenu();
    }
  }

  @action
  toggleBodyScrolling(bool) {
    if (!this.site.mobileView) {
      return;
    }
    scrollLock(bool);
  }

  @action
  setPanelElement(element) {
    this.panelElement = element;
  }

  <template>
    <header class="d-header" {{this.appEventsListeners}}>
      <div class="wrap">
        <Contents
          @sidebarEnabled={{@sidebarEnabled}}
          @toggleHamburger={{this.toggleHamburger}}
          @showSidebar={{@showSidebar}}
        >

          <span class="header-buttons">
            <PluginOutlet @name="before-header-buttons" />

            {{#unless this.currentUser}}
              <AuthButtons
                @showCreateAccount={{@showCreateAccount}}
                @showLogin={{@showLogin}}
                @canSignUp={{@canSignUp}}
              />
            {{/unless}}

            <PluginOutlet @name="after-header-buttons" />
          </span>

          {{#if
            (not (and this.siteSettings.login_required (not this.currentUser)))
          }}
            <Icons
              @sidebarEnabled={{@sidebarEnabled}}
              @toggleSearchMenu={{this.toggleSearchMenu}}
              @toggleHamburger={{this.toggleHamburger}}
              @toggleUserMenu={{this.toggleUserMenu}}
              @searchButtonId={{SEARCH_BUTTON_ID}}
              @panelElement={{this.panelElement}}
            />
          {{/if}}

          {{#if this.search.visible}}
            <SearchMenuWrapper @closeSearchMenu={{this.toggleSearchMenu}} />
          {{else if this.header.hamburgerVisible}}
            <HamburgerDropdownWrapper
              @toggleHamburger={{this.toggleHamburger}}
            />
          {{else if this.header.userVisible}}
            <UserMenuWrapper @toggleUserMenu={{this.toggleUserMenu}} />
          {{/if}}

          <div id="additional-panel-wrapper" {{didInsert this.setPanelElement}}>
          </div>

          {{#if
            (and
              (or this.site.mobileView this.site.narrowDesktopView)
              (or this.header.hamburgerVisible this.header.userVisible)
            )
          }}
            <div class="header-cloak"></div>
          {{/if}}
        </Contents>
      </div>
    </header>
  </template>
}
