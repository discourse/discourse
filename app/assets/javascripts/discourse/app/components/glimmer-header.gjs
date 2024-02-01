import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import scrollLock from "discourse/lib/scroll-lock";
import DiscourseURL from "discourse/lib/url";
import { scrollTop } from "discourse/mixins/scroll-top";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import { isTesting } from "discourse-common/config/environment";
import getURL from "discourse-common/lib/get-url";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";
import { hash } from "discourse-common/lib/helpers";
import { modifier } from "ember-modifier";

import Contents from "./glimmer-header/contents";
import AuthButtons from "./glimmer-header/auth-buttons";
import Icons from "./glimmer-header/icons";
import SearchMenuWrapper from "./glimmer-header/search-menu-wrapper";
import HamburgerDropdownWrapper from "./glimmer-header/hamburger-dropdown-wrapper";
import UserMenuWrapper from "./glimmer-header/user-menu-wrapper";
import MountWidget from "./mount-widget";

const SEARCH_BUTTON_ID = "search-button";

let additionalPanels = [];
export function attachAdditionalPanel(name, toggle, transformAttrs) {
  additionalPanels.push({ name, toggle, transformAttrs });
}

export default class GlimmerHeader extends Component {
  @service router;
  @service search;
  @service currentUser;
  @service site;
  @service appEvents;
  @service register;

  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
  @tracked skipSearchContext = this.site.mobileView;

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

  get inTopicRoute() {
    return this.search.inTopicContext;
  }

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
      const controller = this.register.lookup("controller:topic");
      const total = controller.get("model.postStream.stream.length") || 0;
      const chunkSize = controller.get("model.chunk_size") || 0;
      showSearch =
        total > chunkSize &&
        document.querySelector(
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
    this.userVisible = !this.userVisible;
    this.toggleBodyScrolling(this.userVisible);

    // auto focus on first button in dropdown
    schedule("afterRender", () =>
      document.querySelector(".user-menu button")?.focus()
    );
  }

  @action
  toggleHamburger() {
    if (this.args.sidebarEnabled && !this.site.narrowDesktopView) {
      this.args.toggleSidebar();
    } else {
      this.hamburgerVisible = !this.hamburgerVisible;
      this.toggleBodyScrolling(this.hamburgerVisible);

      schedule("afterRender", () => {
        // Remove focus from hamburger toggle button
        document.querySelector("#toggle-hamburger-menu")?.blur();
      });
    }
  }

  @action
  toggleBodyScrolling(bool) {
    if (!this.site.mobileView) {
      return;
    }
    scrollLock(bool);
  }

  <template>
    <header class="d-header" {{this.appEventsListeners}}>
      <div class="wrap">
        <Contents
          @sidebarEnabled={{@sidebarEnabled}}
          @toggleHamburger={{this.toggleHamburger}}
          @showSidebar={{@showSidebar}}
        >
          {{#unless this.currentUser}}
            <AuthButtons
              @showCreateAccount={{@showCreateAccount}}
              @showLogin={{@showLogin}}
              @canSignUp={{@canSignUp}}
            />
          {{/unless}}
          {{#unless
            (and this.siteSettings.login_required (not this.currentUser))
          }}
            <Icons
              @hamburgerVisible={{this.hamburgerVisible}}
              @userVisible={{this.userVisible}}
              @searchVisible={{this.search.visible}}
              @sidebarEnabled={{@sidebarEnabled}}
              @toggleSearchMenu={{this.toggleSearchMenu}}
              @toggleHamburger={{this.toggleHamburger}}
              @toggleUserMenu={{this.toggleUserMenu}}
              @searchButtonId={{SEARCH_BUTTON_ID}}
            />
          {{/unless}}

          {{#if this.search.visible}}
            <SearchMenuWrapper @closeSearchMenu={{this.toggleSearchMenu}} />
          {{else if this.hamburgerVisible}}
            <HamburgerDropdownWrapper
              @toggleHamburger={{this.toggleHamburger}}
            />
          {{else if this.userVisible}}
            <UserMenuWrapper @toggleUserMenu={{this.toggleUserMenu}} />
          {{/if}}

          {{#each this.additionalPanels as |panel|}}
            {{! we need toggle state and attrs }}
            <MountWidget @widget={{panel.name}} />
          {{/each}}

          {{#if (or this.site.mobileView this.site.narrowDesktopView)}}
            <div class="header-cloak"></div>
          {{/if}}
        </Contents>
      </div>
    </header>
  </template>
}
