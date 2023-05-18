import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

const DARK = "dark";
const LIGHT = "light";

function colorSchemeOverride(type) {
  const lightScheme = document.querySelector("link.light-scheme");
  const darkScheme = document.querySelector("link.dark-scheme");

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

  @tracked colorSchemeOverride = this.default;

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
}
