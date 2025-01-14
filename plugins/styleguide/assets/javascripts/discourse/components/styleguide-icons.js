import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import { afterRender } from "discourse/lib/decorators";
import { REPLACEMENTS } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";

@tagName("section")
@classNames("styleguide-icons")
export default class StyleguideIcons extends Component {
  iconIds = [];

  init() {
    super.init(...arguments);
    this.setIconIds();
  }

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
  }
}
