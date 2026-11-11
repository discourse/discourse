import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import EmbedMode from "discourse/lib/embed-mode";

// Temporary layout controls. This is deliberately not the route/panel API.
export default class PageShellPrototype extends Service {
  @service siteSettings;
  @service router;

  @tracked width = "centered";
  @tracked left = "open";
  @tracked right = "open";
  @tracked footer = "content";
  @tracked leftWidth = 260;
  @tracked rightWidth = 300;

  get enabled() {
    return (
      this.siteSettings.enable_page_shell_prototype &&
      this.siteSettings.enable_main_outlet_grid_layout_change &&
      !EmbedMode.enabled
    );
  }

  get hasRightPanel() {
    return !this.router.currentRouteName?.includes("preferences");
  }

  get style() {
    // Only numbers controlled by the bounded inputs below enter the style.
    return trustHTML(
      `--shell-prototype-left-width: ${this.leftWidth}px; --shell-prototype-right-width: ${this.rightWidth}px;`
    );
  }

  @action
  change(event) {
    const { name, value } = event.target;
    const choices = {
      width: ["centered", "full"],
      left: ["open", "rail", "hidden"],
      right: ["open", "rail", "hidden"],
      footer: ["content", "row", "off"],
    };

    if (choices[name]?.includes(value)) {
      this[name] = value;
    } else if (name === "leftWidth" || name === "rightWidth") {
      const size = Number(value);
      if (Number.isFinite(size)) {
        this[name] = Math.max(200, Math.min(size, 480));
      }
    }
  }

  @action
  toggleLeft() {
    this.left = this.left === "open" ? "hidden" : "open";
  }

  @action
  openLeft() {
    this.left = "open";
  }

  @action
  openRight() {
    this.right = "open";
  }
}
