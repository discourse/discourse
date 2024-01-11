import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
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

export default class GlimmerHeader extends Component {
  @service router;
  @service search;

  @tracked searchVisible = false;
  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
  @tracked inTopicContext = false;
  @tracked skipSearchContext = this.site.mobileView;

  get inTopicRoute() {
    return this.inTopicContext || this.search.inTopicContext;
  }

  get headerIcons() {
    return this.attach("header-icons", {
      hamburgerVisible: this.hamburgerVisible,
      userVisible: this.userVisible,
      searchVisible: this.searchVisible || this.search.visible,
      flagCount: this.args.flagCount,
      user: this.currentUser,
      sidebarEnabled: this.args.sidebarEnabled,
    });
  }

  get contentsAttrs() {
    return {
      contents: this.panels,
      minimized: !!this.args.topic,
    };
  }

  get wrapperAttrs() {
    return { ...this.args, ...this.contentsAttrs };
  }

  constructor() {
    super(...arguments);
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

    this.searchVisible = !this.searchVisible;
    this.search.visible = !this.search.visible;
    this.updateHighlight();

    if (this.searchVisible) {
      // only used by the widget search-menu
      this.focusSearchInput();
    } else {
      this.inTopicContext = false;
      this.search.inTopicContext = false;
    }
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
    <header class={{"d-header"}}>
      <HeaderButtons />
      <HeaderIcons />
      {{#each this.additionalPanels as |panel|}}
        <Panel />
      {{/each}}

      {{#if (or this.searchVisible this.search.visible)}}
        <SearchMenuWrapper
          @inTopicContext={{and this.search.inTopicContext this.inTopicRoute}}
        />
      {{else if this.hamburgerVisible}}
        <HamburgerDropdownWrapper />
      {{else if this.userVisible}}
        <UserMenuWrapper />
      {{/if}}

      {{#if (or this.site.mobileView this.site.narrowDesktopView)}}
        <HeaderCloak />
      {{/if}}
    </header>
  </template>
}

let additionalPanels = [];
export function attachAdditionalPanel(name, toggle, transformAttrs) {
  additionalPanels.push({ name, toggle, transformAttrs });
}

// let additionalPanels = [];
// additionalPanels.forEach((panel) => {
//   if (this.state[panel.toggle]) {
//     additionalPanels.push(
//       this.attach(
//         panel.name,
//         panel.transformAttrs.call(this, this.args, this.state)
//       )
//     );
//   }
// });
