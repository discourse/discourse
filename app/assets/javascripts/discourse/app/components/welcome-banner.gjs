import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchMenu from "discourse/components/search-menu";
import { headerOffset } from "discourse/lib/offset-calculator";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class WelcomeBanner extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;
  @service scrollDirection;

  headerHeight = headerOffset();

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
    if (!this.siteSettings.show_welcome_banner) {
      return false;
    }

    // console.log(
    //   this.scrollDirection.distanceToTop,
    //   headerOffset(),
    //   this.scrollDirection.distanceToTop > headerOffset() * 2
    // );
    if (this.scrollDirection.distanceToTop > headerOffset() * 2) {
      return false;
    }

    return this.displayForRoute;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="welcome-banner">
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
              <SearchMenu />
            </div>
            <PluginOutlet @name="search-banner-below-input" />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
