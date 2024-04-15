import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
}
