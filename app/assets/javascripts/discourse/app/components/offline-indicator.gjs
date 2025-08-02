import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class OfflineIndicator extends Component {
  @service networkConnectivity;

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
          @label="offline_indicator.refresh_page"
          @display="link"
          @action={{this.refresh}}
        />
      </div>
    {{/if}}
  </template>
}
