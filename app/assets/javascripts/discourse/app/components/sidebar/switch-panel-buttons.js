import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SwitchPanelButtons extends Component {
  @service router;
  @service sidebarState;
  @tracked switching = false;

  @action
  switchPanel(panel) {
    this.switching = true;
    this.sidebarState.currentPanel.lastKnownURL = this.router.currentURL;
    const url = panel.lastKnownURL || panel.switchButtonDefaultUrl;
    const destination = url === "/" ? "discovery.latest" : url;
    this.router.transitionTo(destination).then(() => (this.switching = false));
    this.sidebarState.setPanel(panel.key);
  }
}
