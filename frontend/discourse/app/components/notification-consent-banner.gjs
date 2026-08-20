import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class NotificationConsentBanner extends Component {
  @service capabilities;
  @service currentUser;
  @service desktopNotifications;
  @service siteSettings;

  get showNotificationPromptBanner() {
    return (
      this.siteSettings.push_notifications_prompt &&
      !this.desktopNotifications.isNotSupported &&
      this.currentUser &&
      this.capabilities.isPwa &&
      Notification.permission !== "denied" &&
      !this.desktopNotifications.isEnabled &&
      !this.desktopNotifications.consentPromptDismissed &&
      (Notification.permission !== "granted" ||
        this.desktopNotifications.canRestorePushWithoutPrompt)
    );
  }

  @action
  turnon() {
    this.desktopNotifications.enable();
  }

  @action
  dismiss() {
    this.desktopNotifications.dismissConsentPrompt();
  }

  <template>
    {{#if this.showNotificationPromptBanner}}
      <div class="row">
        <div class="consent_banner alert alert-info">
          <span>
            {{i18n "user.desktop_notifications.consent_prompt"}}
            <DButton
              @display="link"
              @action={{this.turnon}}
              @label="user.desktop_notifications.enable"
            />
          </span>
          <DButton
            @icon="xmark"
            @action={{this.dismiss}}
            @title="banner.close"
            class="btn-transparent close"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
