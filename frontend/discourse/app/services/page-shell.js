import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import EmbedMode from "discourse/lib/embed-mode";

// Temporary layout controls. This is deliberately not the route/panel API.
export default class PageShell extends Service {
  @service siteSettings;
  @service router;

  @tracked width = "centered";
  @tracked navigation = "open";
  @tracked context = "open";
  @tracked footer = "content";
  @tracked navigationWidth = 260;
  @tracked contextWidth = 300;
  @tracked contextMaxWidth = Math.max(200, Math.min(1000, window.innerWidth));
  @tracked compactLogo = false;

  get effectiveContextWidth() {
    return Math.min(this.contextWidth, this.contextMaxWidth);
  }

  get enabled() {
    return (
      this.siteSettings.enable_page_shell_prototype &&
      this.siteSettings.enable_main_outlet_grid_layout_change &&
      !EmbedMode.enabled
    );
  }

  get hasContextPanel() {
    return !this.router.currentRouteName?.includes("preferences");
  }

  @action
  change(event) {
    const { name, value } = event.target;
    const choices = {
      width: ["centered", "full"],
      navigation: ["open", "rail", "hidden"],
      context: ["open", "rail", "hidden"],
      footer: ["content", "row", "off"],
    };

    if (choices[name]?.includes(value)) {
      this[name] = value;
    } else if (name === "navigationWidth" || name === "contextWidth") {
      const size = Number(value);
      if (Number.isFinite(size)) {
        const maximum = name === "contextWidth" ? this.contextMaxWidth : 400;
        this[name] = Math.max(200, Math.min(size, maximum));
      }
    }
  }

  @action
  toggleNavigation() {
    this.navigation = this.navigation === "open" ? "hidden" : "open";
  }

  @action
  openNavigation() {
    this.navigation = "open";
  }

  @action
  openContext() {
    this.context = "open";
  }
}
