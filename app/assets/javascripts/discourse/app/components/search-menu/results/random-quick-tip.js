import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

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

resetQuickSearchRandomTips();

export default class RandomQuickTip extends Component {
  constructor() {
    super(...arguments);
    this.randomTip = QUICK_TIPS[Math.floor(Math.random() * QUICK_TIPS.length)];
  }

  @action
  triggerAutocomplete(e) {
    if (e.target.classList.contains("tip-clickable")) {
      this.args.updateTerm(this.randomTip.label);
      const searchInput = document.querySelector("#search-term");
      searchInput.focus();
    }
  }
}
