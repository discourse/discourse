import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { defaultHomepage } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;
  @tracked isSwitching = false;

  @action
  switchPanel(panel) {
    this.isSwitching = true;
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;

    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    const destination =
      url === "/" ? `discovery.${defaultHomepage()}` : getURL(url);

    this.router
      .transitionTo(destination)
      .then(() => {
        this.sidebarState.setPanel(panel.key);
      })
      .finally(() => {
        this.isSwitching = false;
      });
  }
}
