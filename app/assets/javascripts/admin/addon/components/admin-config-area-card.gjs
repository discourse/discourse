import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreaCard extends Component {
  @tracked collapsed = false;

  <template>
    <section class="admin-config-area-card">
      <h3>{{i18n @heading}}</h3>
      <form>
        {{yield}}
      </form>
    </section>
  </template>
}
