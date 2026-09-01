import Component from "@glimmer/component";
import { action } from "@ember/object";
import { countryFlag, countryName } from "discourse/admin/lib/format-country";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const BROWSER_ICONS = {
  android_browser: "fab-android",
  edge: "fab-edge",
  firefox: "fab-firefox-browser",
  chrome: "fab-chrome",
  ie: "fab-internet-explorer",
  opera: "fab-opera",
  qq_browser: "fab-qq",
  safari: "fab-safari",
  unknown: "globe",
};

export default class SiteTrafficExplorerDimensionLabel extends Component {
  get label() {
    return this.args.dimension === "countries"
      ? countryName(this.args.row.value)
      : this.args.row.label;
  }

  @action
  countryFlag(value) {
    return countryFlag(value);
  }

  @action
  browserIcon(value) {
    return BROWSER_ICONS[value] ?? BROWSER_ICONS.unknown;
  }

  <template>
    <span class="site-traffic-explorer__dimension-label">
      {{#if (eq @dimension "countries")}}
        <span
          aria-hidden="true"
          class="site-traffic-explorer__dimension-prefix"
        >{{this.countryFlag @row.value}}</span>
      {{else if (eq @dimension "browsers")}}
        {{dIcon
          (this.browserIcon @row.value)
          class="site-traffic-explorer__dimension-prefix"
        }}
      {{/if}}
      <span class="site-traffic-explorer__dimension-text" title={{this.label}}>
        {{this.label}}
      </span>
    </span>
  </template>
}
