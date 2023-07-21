import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class SwitchPanelButtons extends Component {
  @service router;

  @action
  switchPanel(currentPanel, panel) {
    currentPanel.lastKnownURL = this.router.currentURL;
    this.args.setCurrentPanelKey(panel.key);
    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    if (url === "/") {
      this.router.transitionTo("discovery.latest");
    } else {
      this.router.transitionTo(url);
    }
  }
}
