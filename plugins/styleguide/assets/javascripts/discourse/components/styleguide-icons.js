import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import { REPLACEMENTS } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";

export default Component.extend({
  tagName: "section",
  classNames: ["styleguide-icons"],
  iconIds: [],

  init() {
    this._super(...arguments);
    this.setIconIds();
  },

  @afterRender
  setIconIds() {
    let symbols = document.querySelectorAll("#svg-sprites symbol");
    if (symbols.length > 0) {
      let ids = Array.from(symbols).mapBy("id");
      ids.push(...Object.keys(REPLACEMENTS));
      this.set("iconIds", [...new Set(ids.sort())]);
    } else {
      // Let's try again a short time later if there are no svgs loaded yet
      discourseLater(this, this.setIconIds, 1500);
    }
  },
});
