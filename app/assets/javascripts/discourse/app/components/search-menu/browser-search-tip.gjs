import Component from "@glimmer/component";
import iN from "discourse/helpers/i18n";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class BrowserSearchTip extends Component {<template><div class="browser-search-tip">
  <span class="tip-label">
    {{this.translatedLabel}}
  </span>
  <span class="tip-description">
    {{iN "search.browser_tip_description"}}
  </span>
</div></template>

  get translatedLabel() {
    return i18n("search.browser_tip", { modifier: translateModKey("Meta+") });
  }
}
