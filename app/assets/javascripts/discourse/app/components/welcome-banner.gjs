import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class WelcomeBanner extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;

  @tracked inViewport = true;

  checkViewport = modifier((element) => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        this.inViewport = entry.isIntersecting;
      },
      { threshold: 1.0 }
    );

    observer.observe(element);

    return () => observer.disconnect();
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
      username: prioritizeNameFallback(
        this.currentUser.name,
        this.currentUser.username
      ),
    });
  }

  get shouldDisplay() {
    if (!this.siteSettings.enable_welcome_banner) {
      return false;
    }

    return this.displayForRoute;
  }

  <template>
    {{#if this.shouldDisplay}}
      {{#if this.inViewport}}
        {{bodyClass "welcome-banner--visible"}}
      {{/if}}

      <div class="welcome-banner" {{this.checkViewport}}>
        <div class="custom-search-banner welcome-banner__inner-wrapper">
          <div class="wrap custom-search-banner-wrap welcome-banner__wrap">
            <h1 class="welcome-banner__title">{{htmlSafe this.headerText}}</h1>
            <PluginOutlet @name="welcome-banner-below-headline" />
            <div class="search-menu welcome-banner__search-menu">
              <DButton
                @icon="magnifying-glass"
                @title="search.open_advanced"
                @href="/search?expanded=true"
                class="search-icon"
              />
              <SearchMenu @location="welcome-banner" />
            </div>
            <PluginOutlet @name="search-banner-below-input" />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
