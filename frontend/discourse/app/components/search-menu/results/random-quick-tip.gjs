import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const DEFAULT_QUICK_TIPS = [
  {
    label: "#",
    descriptionKey: "search.tips.category_tag",
    clickable: true,
  },
  {
    label: "@",
    descriptionKey: "search.tips.author",
    clickable: true,
  },
  {
    label: "in:",
    descriptionKey: "search.tips.in",
    clickable: true,
  },
  {
    label: "status:",
    descriptionKey: "search.tips.status",
    clickable: true,
  },
  {
    labelKey: "search.tips.full_search_key",
    labelOptions: { modifier: "Ctrl" },
    descriptionKey: "search.tips.full_search",
  },
  {
    label: "@me",
    descriptionKey: "search.tips.me",
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

  get tipLabel() {
    const tip = this.randomTip;
    if (tip.labelKey) {
      return i18n(tip.labelKey, tip.labelOptions || {});
    }
    return tip.label;
  }

  get tipDescription() {
    const tip = this.randomTip;
    if (tip.descriptionKey) {
      return i18n(tip.descriptionKey);
    }
    return tip.description;
  }

  @action
  tipSelected(e) {
    if (e.target.classList.contains("tip-clickable")) {
      this.args.searchTermChanged(this.tipLabel);
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
        {{this.tipLabel}}
      </button>

      <span id="tip-description">
        {{this.tipDescription}}
      </span>
    </li>
  </template>
}
