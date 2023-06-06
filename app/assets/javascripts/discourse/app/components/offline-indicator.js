import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class OfflineIndicator extends Component {
  @service messageBusConnectivity;
  @service siteSettings;

  get showing() {
    return (
      this.siteSettings.enable_offline_indicator &&
      !this.messageBusConnectivity.connected
    );
  }

  @action
  refresh() {
    window.location.reload(true);
  }
}
