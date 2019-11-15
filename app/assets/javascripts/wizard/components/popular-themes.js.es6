import Component from "@ember/component";
import { POPULAR_THEMES } from "discourse-common/helpers/popular-themes";

export default Component.extend({
  classNames: ["popular-themes"],

  init() {
    this._super(...arguments);

    this.popular_components = this.selectedThemeComponents();
  },

  selectedThemeComponents() {
    return this.shuffle()
      .filter(theme => theme.component)
      .slice(0, 5);
  },

  shuffle() {
    let array = POPULAR_THEMES;

    // https://stackoverflow.com/a/12646864
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }

    return array;
  }
});
