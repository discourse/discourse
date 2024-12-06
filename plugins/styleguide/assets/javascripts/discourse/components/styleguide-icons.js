import { DEBUG } from "@glimmer/env";
import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import { REPLACEMENTS } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";
import { afterRender } from "discourse-common/utils/decorators";

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
      // skip trying it later in debug mode because this was causing the CI to timeout
      if (!DEBUG) {
        // Let's try again a short time later if there are no svgs loaded yet
        discourseLater(this, this.setIconIds, 1500);
      }
    }
  }
}
