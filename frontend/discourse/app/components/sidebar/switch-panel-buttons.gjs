import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;

  @tracked isSwitching = false;

  @action
  async switchPanel(panel) {
    this.isSwitching = true;
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;

    const destination = panel?.switchButtonDefaultUrl;
    if (!destination) {
      return;
    }

    try {
      await this.router.transitionTo(destination).followRedirects();
      this.sidebarState.setPanel(panel.key);
    } catch (e) {
      if (e.name !== "TransitionAborted") {
        throw e;
      }
    } finally {
      this.isSwitching = false;
    }
  }

  <template>
    {{#each @buttons as |button|}}
      <DButton
        @action={{fn this.switchPanel button}}
        @icon={{button.switchButtonIcon}}
        @disabled={{this.isSwitching}}
        @translatedLabel={{button.switchButtonLabel}}
        data-key={{button.key}}
        class="btn-default sidebar__panel-switch-button"
      />
    {{/each}}
  </template>
}
