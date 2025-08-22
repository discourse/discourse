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
    switch (this.siteSettings.welcome_banner_page_visibility) {
      case "top_menu_pages":
        return this.siteSettings.top_menu
          .split("|")
          .any(
            (menuItem) =>
              `discovery.${menuItem}` === this.router.currentRouteName
          );
      case "homepage":
        return (
          this.router.currentRouteName === `discovery.${defaultHomepage()}`
        );
      case "discovery":
        return this.router.currentRouteName.startsWith("discovery.");
      case "all_pages":
        return true;
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
        `background-image: url(${escapeExpression(
          this.siteSettings.welcome_banner_image
        )})`
      );
    }
  }

  <template>
    {{bodyClass this.bodyClasses}}
    {{#if this.shouldDisplay}}
      <div
        style={{if this.bgImgStyle this.bgImgStyle}}
        class={{concatClass
          "welcome-banner"
          this.locationClass
          this.bgImgClass
        }}
        {{this.checkViewport}}
        {{this.handleKeyboardShortcut}}
      >
        <div class="custom-search-banner welcome-banner__inner-wrapper">
          <div class="custom-search-banner-wrap welcome-banner__wrap">
            <div class="welcome-banner__title">
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
              />
            </div>
            <PluginOutlet @name="welcome-banner-below-input" />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
