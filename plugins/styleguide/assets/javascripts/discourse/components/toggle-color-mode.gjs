import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { loadColorSchemeStylesheet } from "discourse/lib/color-scheme-picker";
import { currentThemeId } from "discourse/lib/theme-selector";

const DARK = "dark";
const LIGHT = "light";

function colorSchemeOverride(type) {
  const lightScheme = document.querySelector("link.light-scheme");
  const darkScheme =
    document.querySelector("link.dark-scheme") ||
    document.querySelector("link#cs-preview-dark");

  if (!lightScheme && !darkScheme) {
    return;
  }

  switch (type) {
    case DARK:
      lightScheme.origMedia = lightScheme.media;
      lightScheme.media = "none";
      darkScheme.origMedia = darkScheme.media;
      darkScheme.media = "all";
      break;
    case LIGHT:
      lightScheme.origMedia = lightScheme.media;
      lightScheme.media = "all";
      darkScheme.origMedia = darkScheme.media;
      darkScheme.media = "none";
      break;
    default:
      if (lightScheme.origMedia) {
        lightScheme.media = lightScheme.origMedia;
        lightScheme.removeAttribute("origMedia");
      }
      if (darkScheme.origMedia) {
        darkScheme.media = darkScheme.origMedia;
        darkScheme.removeAttribute("origMedia");
      }
      break;
  }
}

export default class ToggleColorMode extends Component {
  @service keyValueStore;
  @service siteSettings;

  @tracked colorSchemeOverride = this.default;
  @tracked shouldRender = true;

  constructor() {
    super(...arguments);

    // If site has a dark color scheme set but user doesn't auto switch in dark mode
    // we need to load the stylesheet manually
    if (!document.querySelector("link.dark-scheme")) {
      if (this.siteSettings.default_dark_mode_color_scheme_id > 0) {
        loadColorSchemeStylesheet(
          this.siteSettings.default_dark_mode_color_scheme_id,
          currentThemeId(),
          true
        );
      } else {
        // no dark color scheme available, hide button
        this.shouldRender = false;
      }
    }
  }

  get default() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? DARK
      : LIGHT;
  }

  @action
  toggle() {
    this.colorSchemeOverride = this.colorSchemeOverride === DARK ? LIGHT : DARK;
    colorSchemeOverride(this.colorSchemeOverride);
  }

  <template>
    {{#if this.shouldRender}}
      <DButton @action={{this.toggle}} class="toggle-color-mode">Toggle color</DButton>
    {{/if}}
  </template>
}
