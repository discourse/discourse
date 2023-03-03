import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class RandomQuickTip extends Component {
  constructor() {
    super(...arguments);

    return QUICK_TIPS[Math.floor(Math.random() * QUICK_TIPS.length)];
  }

  @action
  triggerAutocomplete(e) {
    if (e.target.classList.contains("tip-clickable")) {
      const searchInput = document.querySelector("#search-term");
      searchInput.value = this.state.label;
      searchInput.focus();
      this.sendWidgetAction("triggerAutocomplete", {
        value: this.state.label,
        searchTopics: this.state.searchTopics,
      });
    }
  }
}
