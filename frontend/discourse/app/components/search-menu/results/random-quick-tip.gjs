import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const DEFAULT_QUICK_TIPS = [
  {
    label: "#",
    description: i18n("search.tips.category_tag"),
    clickable: true,
  },
  {
    label: "@",
    description: i18n("search.tips.author"),
    clickable: true,
  },
  {
    label: "in:",
    description: i18n("search.tips.in"),
    clickable: true,
  },
  {
    label: "status:",
    description: i18n("search.tips.status"),
    clickable: true,
  },
  {
    shortcut: "mod+enter",
    description: i18n("search.tips.full_search"),
  },
  {
    label: "@me",
    description: i18n("search.tips.me"),
  },
];

let QUICK_TIPS = [];

export function addQuickSearchRandomTip(tip) {
  if (!QUICK_TIPS.includes(tip)) {
    QUICK_TIPS.push(tip);
  }
}

export function resetQuickSearchRandomTips() {
  QUICK_TIPS = [].concat(DEFAULT_QUICK_TIPS);
}

export function removeDefaultQuickSearchRandomTips() {
  QUICK_TIPS = QUICK_TIPS.filter((tip) => !DEFAULT_QUICK_TIPS.includes(tip));
}

resetQuickSearchRandomTips();

export default class RandomQuickTip extends Component {
  @service capabilities;
  @service search;

  constructor() {
    super(...arguments);
    // A tip about a key combination is no help without a keyboard to press
    // it. The pick is made once per instance, so a keyboard noticed later
    // shows up on the next open.
    const tips = QUICK_TIPS.filter(
      (tip) => !tip.shortcut || this.capabilities.hasKeyboard
    );
    this.randomTip = tips[Math.floor(Math.random() * tips.length)];
  }

  @action
  tipSelected(e) {
    if (e.target.classList.contains("tip-clickable")) {
      this.args.searchTermChanged(this.randomTip.label);
      this.search.focusSearchInput();

      e.stopPropagation();
      e.preventDefault();
    }
  }

  <template>
    <li class="search-random-quick-tip">
      <button
        class={{dConcatClass
          "tip-label"
          (if this.randomTip.clickable "tip-clickable")
        }}
        {{on "click" this.tipSelected}}
        aria-describedby="tip-description"
      >
        {{#if this.randomTip.shortcut}}
          <DShortcut @keys={{this.randomTip.shortcut}} />
        {{else}}
          {{this.randomTip.label}}
        {{/if}}
      </button>

      <span id="tip-description">
        {{this.randomTip.description}}
      </span>
    </li>
  </template>
}
