import Component from "@glimmer/component";
import { action } from "@ember/object";
import { countryFlag } from "discourse/admin/lib/format-country";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const BROWSER_ICONS = {
  edge: "fab-microsoft",
  firefox: "fab-firefox-browser",
  chrome: "fab-chrome",
  safari: "fab-apple",
  unknown: "globe",
};

export default class SiteTrafficExplorerDimensionLabel extends Component {
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
        <span aria-hidden="true">{{this.countryFlag @row.value}}</span>
      {{else if (eq @dimension "browsers")}}
        {{dIcon (this.browserIcon @row.value)}}
      {{/if}}
      <span class="site-traffic-explorer__dimension-text">{{@row.label}}</span>
    </span>
  </template>
}
