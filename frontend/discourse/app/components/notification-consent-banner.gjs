import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { keyValueStore as pushNotificationKeyValueStore } from "discourse/lib/push-notifications";
import { i18n } from "discourse-i18n";

const userDismissedPromptKey = "dismissed-prompt";

export default class NotificationConsentBanner extends Component {
  @service capabilities;
  @service currentUser;
  @service desktopNotifications;
  @service siteSettings;

  @tracked bannerDismissed;

  constructor() {
    super(...arguments);
    this.bannerDismissed = pushNotificationKeyValueStore.getItem(
      userDismissedPromptKey
    );
  }

  setBannerDismissed(value) {
    pushNotificationKeyValueStore.setItem(userDismissedPromptKey, value);
    this.bannerDismissed = pushNotificationKeyValueStore.getItem(
      userDismissedPromptKey
    );
  }

  get showNotificationPromptBanner() {
    return (
      this.siteSettings.push_notifications_prompt &&
      !this.desktopNotifications.isNotSupported &&
      this.currentUser &&
      this.capabilities.isPwa &&
      Notification.permission !== "denied" &&
      Notification.permission !== "granted" &&
      !this.desktopNotifications.isEnabled &&
      !this.bannerDismissed
    );
  }

  @action
  turnon() {
    this.desktopNotifications.enable();
    this.setBannerDismissed(true);
  }

  @action
  dismiss() {
    this.setBannerDismissed(false);
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
