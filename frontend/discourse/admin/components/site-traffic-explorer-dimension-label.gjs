import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { countryFlag } from "discourse/admin/lib/format-country";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";

const BROWSER_ICONS = {
  edge: "fab-microsoft",
  firefox: "fab-firefox-browser",
  chrome: "fab-chrome",
  safari: "fab-apple",
  unknown: "globe",
};

export default class SiteTrafficExplorerDimensionLabel extends Component {
  @service tooltip;

  @tracked isTruncated = false;

  registerTooltip = modifier((element, [content, isTruncated]) => {
    if (!isTruncated) {
      return;
    }

    const tooltip = this.tooltip.register(element, {
      content,
      triggers: { desktop: ["hover"], mobile: [] },
      untriggers: { desktop: ["hover"], mobile: [] },
    });

    return () => tooltip.destroy();
  });

  @action
  countryFlag(value) {
    return countryFlag(value);
  }

  @action
  browserIcon(value) {
    return BROWSER_ICONS[value] ?? BROWSER_ICONS.unknown;
  }

  @action
  measure(element) {
    this.isTruncated = element.scrollWidth > element.clientWidth;
  }

  @action
  measureResize(entries) {
    this.measure(entries[0].target);
  }

  <template>
    <span class="site-traffic-explorer__dimension-label">
      {{#if (eq @dimension "countries")}}
        <span aria-hidden="true">{{this.countryFlag @row.value}}</span>
      {{else if (eq @dimension "browsers")}}
        {{dIcon (this.browserIcon @row.value)}}
      {{/if}}
      <span
        class="site-traffic-explorer__dimension-text"
        {{didInsert this.measure}}
        {{didUpdate this.measure @row.label}}
        {{dOnResize this.measureResize}}
        {{this.registerTooltip @row.label this.isTruncated}}
      >{{@row.label}}</span>
    </span>
  </template>
}
