import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { focusSearchInput } from "discourse/components/search-menu";
import I18n from "discourse-i18n";

const DEFAULT_QUICK_TIPS = [
  {
    label: "#",
    description: I18n.t("search.tips.category_tag"),
    clickable: true,
  },
  {
    label: "@",
    description: I18n.t("search.tips.author"),
    clickable: true,
  },
  {
    label: "in:",
    description: I18n.t("search.tips.in"),
    clickable: true,
  },
  {
    label: "status:",
    description: I18n.t("search.tips.status"),
    clickable: true,
  },
  {
    label: I18n.t("search.tips.full_search_key", { modifier: "Ctrl" }),
    description: I18n.t("search.tips.full_search"),
  },
  {
    label: "@me",
    description: I18n.t("search.tips.me"),
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
      focusSearchInput();

      e.stopPropagation();
      e.preventDefault();
    }
  }
}
