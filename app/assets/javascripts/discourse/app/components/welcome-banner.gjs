import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

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
    return this.siteSettings.top_menu
      .split("|")
      .any(
        (menuItem) => `discovery.${menuItem}` === this.router.currentRouteName
      );
  }

  get headerText() {
    if (!this.currentUser) {
      return i18n("welcome_banner.header.anonymous_members", {
        site_name: this.siteSettings.title,
      });
    }

    return i18n("welcome_banner.header.logged_in_members", {
      preferred_display_name: prioritizeNameFallback(
        this.currentUser.name,
        this.currentUser.username
      ),
    });
  }

  get subheaderText() {
    return this.currentUser
      ? i18n("welcome_banner.subheader.logged_in_members")
      : i18n("welcome_banner.subheader.anonymous_members");
  }

  get shouldDisplay() {
    const enabled = applyValueTransformer(
      "site-setting-enable-welcome-banner",
      this.siteSettings.enable_welcome_banner
    );

    if (!enabled) {
      return false;
    }

    return this.displayForRoute;
  }

  get bodyClasses() {
    return this.shouldDisplay && this.search.welcomeBannerSearchInViewport
      ? "welcome-banner--enabled welcome-banner--visible"
      : this.shouldDisplay
        ? "welcome-banner--enabled"
        : "";
  }

  <template>
    {{bodyClass this.bodyClasses}}
    {{#if this.shouldDisplay}}

      <div
        class="welcome-banner"
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
