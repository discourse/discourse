import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class SwitchPanelButtons extends Component {
  @service router;

  constructor() {
    super(...arguments);
    this.setCurrentPanelKey = this.args.setCurrentPanelKey;
  }

  @action
  switchPanel(currentPanel, panel) {
    currentPanel.lastKnownURL = this.router.currentURL;
    this.setCurrentPanelKey(panel.key);
    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    if (url === "/") {
      this.router.transitionTo("discovery.latest");
    } else {
      this.router.transitionTo(url);
    }
  }
}
