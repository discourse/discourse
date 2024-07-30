import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "discourse-i18n";

export default class AdminConfigAreaCard extends Component {
  @tracked collapsed = false;

  get computedHeading() {
    if (this.args.heading) {
      return I18n.t(this.args.heading);
    }
    return this.args.translatedHeading;
  }

  <template>
    <section class="admin-config-area-card" ...attributes>
      <h3 class="admin-config-area-card__title">{{this.computedHeading}}</h3>
      <div class="admin-config-area-card__content">
        {{yield}}
      </div>
    </section>
  </template>
}
