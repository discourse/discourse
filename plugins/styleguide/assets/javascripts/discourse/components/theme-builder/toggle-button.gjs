import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ThemeBuilderToggleButton extends Component {
  @service currentUser;
  @service themeBuilderState;

  get isVisible() {
    return this.currentUser?.admin;
  }

  @action
  handleToggle() {
    this.themeBuilderState.toggle();
  }

  <template>
    {{#if this.isVisible}}
      <DButton
        @action={{this.handleToggle}}
        @icon="paintbrush"
        @label="styleguide.theme_builder.toggle"
        class="btn-default theme-builder-toggle"
      />
    {{/if}}
  </template>
}
