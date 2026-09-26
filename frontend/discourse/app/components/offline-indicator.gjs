import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import NetworkConnectivityService from "discourse/services/network-connectivity";

export default class OfflineIndicator extends Component {
  @service(() => NetworkConnectivityService) networkConnectivity;

  get showing() {
    return !this.networkConnectivity.connected;
  }

  @action
  refresh() {
    window.location.reload(true);
  }

  <template>
    {{#if this.showing}}
      <div class="offline-indicator">
        <span>{{i18n "offline_indicator.no_internet"}}</span>
        <DButton
          @action={{this.refresh}}
          @display="link"
          @label="offline_indicator.refresh_page"
        />
      </div>
    {{/if}}
  </template>
}
