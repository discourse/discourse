import Component from "@glimmer/component";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { sanitize } from "discourse/lib/text";
import { defaultHomepage, escapeExpression } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

export const ALL_PAGES_EXCLUDED_ROUTES = [
  "account-created.edit-email",
  "account-created.index",
  "account-created.resent",
  "activate-account",
  "full-page-search",
  "invites.show",
  "login",
  "password-reset",
  "signup",
];

export default class WelcomeBanner extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;
  @service appEvents;
  @service search;

  checkViewport = modifier((element) => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        this.search.welcomeBannerSearchInViewport = entry.isIntersecting;
      },
      { threshold: 1.0 }
    );

    observer.observe(element);

    return () => {
      observer.disconnect();
      this.search.welcomeBannerSearchInViewport = false;
    };
  });

  handleKeyboardShortcut = modifier(() => {
    const cb = (appEvent) => {
      if (
        appEvent.type === "search" &&
        this.search.welcomeBannerSearchInViewport
      ) {
        this.search.focusSearchInput();
        appEvent.event.preventDefault();
      }
    };
    this.appEvents.on("header:keyboard-trigger", cb);
    return () => this.appEvents.off("header:keyboard-trigger", cb);
  });

  get displayForRoute() {
    const { currentRouteName } = this.router;
    const { top_menu, welcome_banner_page_visibility } = this.siteSettings;

    switch (welcome_banner_page_visibility) {
      case "top_menu_pages":
        return top_menu
          .split("|")
          .any((menuItem) => `discovery.${menuItem}` === currentRouteName);
      case "homepage":
        return currentRouteName === `discovery.${defaultHomepage()}`;
      case "discovery":
        return currentRouteName.startsWith("discovery.");
      case "all_pages":
        return (
          !currentRouteName.startsWith("admin") &&
          !ALL_PAGES_EXCLUDED_ROUTES.some(
            (routeName) => routeName === currentRouteName
          )
        );
      default:
        return false;
    }
  }

  get headerText() {
    if (!this.currentUser) {
      return i18n("welcome_banner.header.anonymous_members", {
        site_name: this.siteSettings.title,
      });
    }

    return i18n("welcome_banner.header.logged_in_members", {
      preferred_display_name: sanitize(
        prioritizeNameFallback(this.currentUser.name, this.currentUser.username)
      ),
    });
  }

  get subheaderText() {
    const memberKey = this.currentUser
      ? "logged_in_members"
      : "anonymous_members";
    return I18n.lookup(`welcome_banner.subheader.${memberKey}`);
  }

  get shouldDisplay() {
    return this.siteSettings.enable_welcome_banner && this.displayForRoute;
  }

  get bodyClasses() {
    return this.shouldDisplay && this.search.welcomeBannerSearchInViewport
      ? "welcome-banner--enabled welcome-banner--visible"
      : this.shouldDisplay
        ? "welcome-banner--enabled"
        : "";
  }

  get locationClass() {
    return `--location-${dasherize(this.siteSettings.welcome_banner_location)}`;
  }

  get bgImgClass() {
    if (this.siteSettings.welcome_banner_image) {
      return `--with-bg-img`;
    }
  }

  get bgImgStyle() {
    if (this.siteSettings.welcome_banner_image) {
      return htmlSafe(
        `background-image:url(${escapeExpression(
          this.siteSettings.welcome_banner_image
        )});`
      );
    }
  }

  get textColorStyle() {
    if (
      this.siteSettings.welcome_banner_image &&
      this.siteSettings.welcome_banner_text_color
    ) {
      return htmlSafe(
        `color:${escapeExpression(this.siteSettings.welcome_banner_text_color)};`
      );
    }
  }

  <template>
    {{bodyClass this.bodyClasses}}
    {{#if this.shouldDisplay}}
      <div
        class={{concatClass
          "welcome-banner"
          this.locationClass
          this.bgImgClass
        }}
        {{this.checkViewport}}
        {{this.handleKeyboardShortcut}}
      >
        <div
          class="custom-search-banner-wrap welcome-banner__wrap"
          style={{if this.bgImgStyle this.bgImgStyle}}
        >
          <div
            class="welcome-banner__title"
            style={{if this.textColorStyle this.textColorStyle}}
          >
            {{htmlSafe this.headerText}}
            {{#if this.subheaderText}}
              <p class="welcome-banner__subheader">
                {{htmlSafe this.subheaderText}}
              </p>
            {{/if}}
          </div>
          <PluginOutlet @name="welcome-banner-below-headline" />
          <div class="search-menu welcome-banner__search-menu">
            <DButton
              @icon="magnifying-glass"
              @title="search.open_advanced"
              @href="/search?expanded=true"
              class="search-icon"
            />
            <SearchMenu
              @location="welcome-banner"
              @searchInputId="welcome-banner-search-input"
              @placeholder={{i18n "welcome_banner.search"}}
            />
          </div>
          <PluginOutlet @name="welcome-banner-below-input" />
        </div>
      </div>
    {{/if}}
  </template>
}
