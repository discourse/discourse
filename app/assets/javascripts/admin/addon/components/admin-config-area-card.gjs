import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreaCard extends Component {
  @tracked collapsed = false;

  <template>
    <section class="admin-config-area-card" ...attributes>
      <h3 class="admin-config-area-card__title">{{i18n @heading}}</h3>
      <div class="admin-config-area-card__content">
        {{yield}}
      </div>
    </section>
  </template>
}
