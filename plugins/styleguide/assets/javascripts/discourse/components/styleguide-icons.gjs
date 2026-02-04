/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { afterRender } from "discourse/lib/decorators";
import { REPLACEMENTS } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";

@tagName("")
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
      let ids = Array.from(symbols).map((item) => item.id);
      ids.push(...Object.keys(REPLACEMENTS));
      this.set("iconIds", uniqueItemsFromArray(ids).sort());
    } else {
      // Let's try again a short time later if there are no svgs loaded yet
      discourseLater(this, this.setIconIds, 1500);
    }
  }

  <template>
    <section class="styleguide-icons" ...attributes>
      {{#each this.iconIds as |id|}}
        <div class="styleguide-icon">
          {{icon id}}
          <span>{{id}}</span>
        </div>
      {{/each}}
    </section>
  </template>
}
