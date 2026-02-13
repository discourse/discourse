import Component from "@glimmer/component";
import { service } from "@ember/service";
import ThemeBuilderPanel from "discourse/plugins/styleguide/discourse/components/theme-builder/panel";

export default class ThemeBuilderConnector extends Component {
  @service currentUser;

  get isVisible() {
    return this.currentUser?.admin;
  }

  <template>
    {{#if this.isVisible}}
      <ThemeBuilderPanel />
    {{/if}}
  </template>
}
