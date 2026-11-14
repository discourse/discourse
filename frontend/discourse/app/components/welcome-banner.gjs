import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import WelcomeBannerSearch from "discourse/components/welcome-banner-search";
import bodyClass from "discourse/helpers/body-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { defaultHomepage, escapeExpression } from "discourse/lib/utilities";
import {
  welcomeBannerHeader,
  welcomeBannerSubheader,
} from "discourse/lib/welcome-banner-text";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const claimedLocations = new Map();
const reportedLocations = new Set();

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

/** Name of the block that replaces this banner when a layout places it. */
export const WELCOME_BANNER_BLOCK = "welcome-banner";

export default class WelcomeBanner extends Component {
  @service blocks;
  @service router;
  @service site;
  @service siteSettings;
  @service currentUser;

  constructor() {
    super(...arguments);

    const { location } = this.args;
    if (location === undefined) {
      return;
    }

    claimedLocations.set(location, (claimedLocations.get(location) ?? 0) + 1);
    registerDestructor(this, () => {
      const remaining = claimedLocations.get(location) - 1;
      if (remaining > 0) {
        claimedLocations.set(location, remaining);
      } else {
        claimedLocations.delete(location);
      }
    });

    // Other render points are constructed in this same pass, so wait for them
    // before deciding that nobody claimed the location.
    schedule("afterRender", this, this.#reportUnclaimedLocation);
  }

  // Where the banner renders. Core offers the site setting's locations; a
  // customization can return a location of its own and render the banner independently,
  // as long as it passes a @location that matches the transformer's value
  get location() {
    return applyValueTransformer(
      "welcome-banner-location",
      this.siteSettings.welcome_banner_location
    );
  }

  // A bare <WelcomeBanner> without a @location arg will render regardless of the claimed location
  get matchesLocation() {
    return (
      this.args.location === undefined || this.args.location === this.location
    );
  }

  get displayForRoute() {
    const { currentRouteName } = this.router;
    const { top_menu, welcome_banner_page_visibility } = this.siteSettings;

    const shouldDisplayForRoute = this.#shouldDisplayForRoute(
      welcome_banner_page_visibility,
      top_menu,
      currentRouteName
    );

    return applyValueTransformer(
      "welcome-banner-display-for-route",
      shouldDisplayForRoute,
      {
        welcomeBannerPageVisibility: welcome_banner_page_visibility,
        currentRouteName,
        homepage: `discovery.${defaultHomepage()}`,
      }
    );
  }

  get headerText() {
    return welcomeBannerHeader({
      currentUser: this.currentUser,
      siteTitle: this.siteSettings.title,
    });
  }

  get subheaderText() {
    return welcomeBannerSubheader({ currentUser: this.currentUser });
  }

  // A layout that places the welcome banner block takes over from the
  // setting-driven banner on every page, whatever the settings say.
  get replacedByBlock() {
    return this.blocks.isBlockPlaced(WELCOME_BANNER_BLOCK);
  }

  get shouldDisplay() {
    return (
      this.siteSettings.enable_welcome_banner &&
      !this.replacedByBlock &&
      this.matchesLocation &&
      this.displayForRoute
    );
  }

  get bodyClasses() {
    return this.shouldDisplay ? "welcome-banner--enabled" : "";
  }

  get locationClass() {
    return `--location-${dasherize(this.location)}`;
  }

  get bgImgClass() {
    if (this.siteSettings.welcome_banner_image) {
      return `--with-bg-img`;
    }
  }

  get bgImgStyle() {
    if (this.siteSettings.welcome_banner_image) {
      return trustHTML(
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
      return trustHTML(
        `color:${escapeExpression(this.siteSettings.welcome_banner_text_color)};`
      );
    }
  }

  #reportUnclaimedLocation() {
    if (this.isDestroying) {
      return;
    }

    const { location } = this;
    if (
      !this.siteSettings.enable_welcome_banner ||
      this.replacedByBlock ||
      !this.displayForRoute ||
      claimedLocations.has(location) ||
      reportedLocations.has(location)
    ) {
      return;
    }

    reportedLocations.add(location);
    // eslint-disable-next-line no-console
    console.warn(
      `Welcome banner: no render point for location "${location}", so the ` +
        `banner will not be shown. Either render <WelcomeBanner @location="${location}" /> ` +
        "where you want it, or check the value returned by the " +
        "welcome-banner-location transformer."
    );
  }

  #shouldDisplayForRoute(
    welcome_banner_page_visibility,
    top_menu,
    currentRouteName
  ) {
    switch (welcome_banner_page_visibility) {
      case "top_menu_pages":
        return top_menu
          .split("|")
          .some((menuItem) => `discovery.${menuItem}` === currentRouteName);
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

  <template>
    {{bodyClass this.bodyClasses}}
    {{#if this.shouldDisplay}}
      <div
        class={{dConcatClass
          "welcome-banner"
          this.locationClass
          this.bgImgClass
        }}
      >
        <div
          class="custom-search-banner-wrap welcome-banner__wrap"
          style={{if this.bgImgStyle this.bgImgStyle}}
        >
          <div
            class="welcome-banner__title"
            style={{if this.textColorStyle this.textColorStyle}}
          >
            {{trustHTML this.headerText}}
            {{#if this.subheaderText}}
              <p class="welcome-banner__subheader">
                {{trustHTML this.subheaderText}}
              </p>
            {{/if}}
          </div>
          <PluginOutlet @name="welcome-banner-below-headline" />
          {{#if this.site.can_search}}
            <WelcomeBannerSearch
              @placeholder="welcome_banner.search_placeholder"
            />
          {{/if}}
          <PluginOutlet @name="welcome-banner-below-input" />
        </div>
      </div>
    {{/if}}
  </template>
}
