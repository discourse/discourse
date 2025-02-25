import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchMenu from "discourse/components/search-menu";
import { i18n } from "discourse-i18n";

export default class WelcomeBanner extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;

  // @action
  // willDestroy() {
  //   super.willDestroy(...arguments);
  //   document.documentElement.classList.remove("display-search-banner");
  // }

  get displayForRoute() {
    const showOn = settings.show_on;
    const currentRouteName = this.router.currentRouteName;

    if (showOn === "homepage") {
      return currentRouteName === `discovery.${defaultHomepage()}`;
    } else if (showOn === "top_menu") {
      return this.siteSettings.top_menu
        .split("|")
        .any((m) => `discovery.${m}` === currentRouteName);
    } else if (showOn === "discovery") {
      return currentRouteName.startsWith("discovery.");
    } else {
      // "all"
      return (
        currentRouteName !== "full-page-search" &&
        !currentRouteName.startsWith("admin.")
      );
    }
  }

  get displayForUser() {
    const showFor = settings.show_for;
    return (
      showFor === "everyone" ||
      (showFor === "logged_out" && !this.currentUser) ||
      (showFor === "logged_in" && this.currentUser)
    );
  }

  // get buttonText() {
  //   const buttonText = i18n(themePrefix("search_banner.search_button_text"));
  //   // this is required for when the English (US) locale is empty
  //   // and the site locale is set to another language
  //   // otherwise the English (US) fallback key is rendered as the button text
  //   // https://meta.discourse.org/t/bug-with-search-banner-search-button-text-shown-in-search-banner-theme-component/273628
  //   if (buttonText.includes("theme_translations")) {
  //     return false;
  //   }

  //   return buttonText;
  // }

  get shouldDisplay() {
    return this.displayForRoute && this.displayForUser;
  }

  // @action
  // didInsert() {
  //   // Setting a class on <html> from a component is not great
  //   // but we need it for backwards compatibility
  //   document.documentElement.classList.add("display-search-banner");
  // }

  <template>
    <div class="welcome-banner">
      <div class="custom-search-banner welcome-banner__inner-wrapper">
        <div class="wrap custom-search-banner-wrap welcome-banner__wrap">
          <h1>{{htmlSafe (i18n "welcome_banner.header.logged_in_members")}}</h1>
          <PluginOutlet @name="welcome-banner-below-headline" />
          <p>{{htmlSafe
              (i18n "welcome_banner.subheader.logged_in_members")
            }}</p>
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
  </template>
}
