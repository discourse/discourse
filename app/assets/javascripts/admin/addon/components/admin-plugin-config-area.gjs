import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class AdminPluginConfigArea extends Component {
  @service adminPluginNavManager;

  linkText(navLink) {
    if (navLink.label) {
      return i18n(navLink.label);
    } else {
      return navLink.text;
    }
  }

  <template>
    <section class="admin-plugin-config-area">
      {{yield}}
    </section>
  </template>
}
