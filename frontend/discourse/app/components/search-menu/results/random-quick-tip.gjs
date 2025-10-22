import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
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
    label: i18n("search.tips.full_search_key", { modifier: "Ctrl" }),
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
  @service search;

  constructor() {
    super(...arguments);
    this.randomTip = QUICK_TIPS[Math.floor(Math.random() * QUICK_TIPS.length)];
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
        class={{concatClass
          "tip-label"
          (if this.randomTip.clickable "tip-clickable")
        }}
        {{on "click" this.tipSelected}}
        aria-describedby="tip-description"
      >
        {{this.randomTip.label}}
      </button>

      <span id="tip-description">
        {{this.randomTip.description}}
      </span>
    </li>
  </template>
}
