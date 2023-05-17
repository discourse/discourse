import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

const DARK = "dark";
const LIGHT = "light";

function colorSchemeOverride(type) {
  const lightScheme = document.querySelector("link.light-scheme");
  const darkScheme = document.querySelector("link.dark-scheme");

  if (!lightScheme || !darkScheme) {
    return;
  }

  switch (type) {
    case DARK:
      lightScheme.media = "none";
      darkScheme.media = "all";
      break;
    case LIGHT:
      lightScheme.media = "all";
      darkScheme.media = "none";
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
