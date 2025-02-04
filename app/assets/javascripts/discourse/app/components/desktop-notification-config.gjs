import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class DesktopNotificationsConfig extends Component {
  @service desktopNotifications;

  <template>
    <div class="controls">
      {{#if this.desktopNotifications.isNotSupported}}
        <DButton
          @icon="bell-slash"
          @label="user.desktop_notifications.not_supported"
          @disabled="true"
          class="btn-default"
        />
      {{/if}}
      {{#if this.desktopNotifications.isDeniedPermission}}
        <DButton
          @icon="bell-slash"
          @label="user.desktop_notifications.perm_denied_btn"
          @disabled="true"
          class="btn-default"
        />
        <span>
          {{i18n "user.desktop_notifications.perm_denied_expl"}}
        </span>
      {{else}}
        {{#if this.desktopNotifications.isSubscribed}}
          <DButton
            @icon="far-bell-slash"
            @label="user.desktop_notifications.disable"
            @action={{this.desktopNotifications.disable}}
            class="btn-default"
          />
        {{else}}
          <DButton
            @icon="far-bell"
            @label="user.desktop_notifications.enable"
            @action={{this.desktopNotifications.enable}}
            class="btn-default"
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
