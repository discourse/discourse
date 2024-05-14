import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { defaultHomepage } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;

  @tracked currentPanel;
  @tracked isSwitching = false;

  get destination() {
    if (this.currentPanel) {
      const url =
        this.currentPanel.switchButtonDefaultUrl ||
        this.currentPanel.lastKnownURL;
      return url === "/" ? `discovery.${defaultHomepage()}` : getURL(url);
    }
    return null;
  }

  @action
  async switchPanel(panel) {
    this.isSwitching = true;
    this.currentPanel = panel;
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;

    if (this.destination) {
      try {
        await this.router.transitionTo(this.destination).followRedirects();
        this.sidebarState.setPanel(this.currentPanel.key);
      } catch (e) {
        if (e.name !== "TransitionAborted") {
          throw e;
        }
      } finally {
        this.isSwitching = false;
      }
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
