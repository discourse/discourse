import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;

  @action
  switchPanel(panel) {
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;
    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    const destination = url === "/" ? "discovery.latest" : url;
    this.router
      .transitionTo(destination)
      .then(() => this.sidebarState.setPanel(panel.key));
  }
}
