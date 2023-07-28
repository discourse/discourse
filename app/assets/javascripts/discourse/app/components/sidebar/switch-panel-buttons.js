import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;

  @action
  switchPanel(currentPanel, panel) {
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;
    this.sidebarState.setPanel(panel.key);
    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    if (url === "/") {
      this.router.transitionTo("discovery.latest");
    } else {
      this.router.transitionTo(url);
    }
  }
}
