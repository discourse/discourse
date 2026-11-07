import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class HamiltonGreeting extends Component {
  @service siteSettings;

  <template>
    <div class="hamilton__greeting">
      <h1>{{i18n
          "hamilton.greeting"
          value=this.siteSettings.hamilton_greeting
        }}</h1>
    </div>
  </template>
}
