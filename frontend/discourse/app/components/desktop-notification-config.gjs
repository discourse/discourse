import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class DesktopNotificationsConfig extends Component {
  @service desktopNotifications;

  <template>
    <div class="controls">
      {{#if this.desktopNotifications.isNotSupported}}
        <DButton
          class="btn-default"
          @disabled="true"
          @icon="bell-slash"
          @label="user.desktop_notifications.not_supported"
        />
      {{/if}}
      {{#if this.desktopNotifications.isDeniedPermission}}
        <DButton
          class="btn-default"
          @disabled="true"
          @icon="bell-slash"
          @label="user.desktop_notifications.perm_denied_btn"
        />
        <span>
          {{i18n "user.desktop_notifications.perm_denied_expl"}}
        </span>
      {{else}}
        {{#if this.desktopNotifications.isSubscribed}}
          <DButton
            class="btn-default"
            @action={{this.desktopNotifications.disable}}
            @icon="far-bell-slash"
            @label="user.desktop_notifications.disable"
          />
        {{else}}
          <DButton
            class="btn-default"
            @action={{this.desktopNotifications.enable}}
            @icon="far-bell"
            @label="user.desktop_notifications.enable"
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
