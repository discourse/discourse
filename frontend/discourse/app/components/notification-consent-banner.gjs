import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { keyValueStore as pushNotificationKeyValueStore } from "discourse/lib/push-notifications";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import CapabilitiesService from "discourse/services/capabilities";
import CurrentUserService from "discourse/services/current-user";
import DesktopNotificationsService from "discourse/services/desktop-notifications";
import SiteSettingsService from "discourse/services/site-settings";

const userDismissedPromptKey = "dismissed-prompt";

export default class NotificationConsentBanner extends Component {
  @service(() => CapabilitiesService) capabilities;
  @service(() => CurrentUserService) currentUser;
  @service(() => DesktopNotificationsService) desktopNotifications;
  @service(() => SiteSettingsService) siteSettings;

  @tracked bannerDismissed;

  constructor() {
    super(...arguments);
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

  setBannerDismissed(value) {
    pushNotificationKeyValueStore.setItem(userDismissedPromptKey, value);
    this.bannerDismissed = pushNotificationKeyValueStore.getItem(
      userDismissedPromptKey
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
              @action={{this.turnon}}
              @display="link"
              @label="user.desktop_notifications.enable"
            />
          </span>
          <DButton
            class="btn-transparent close"
            @action={{this.dismiss}}
            @icon="xmark"
            @title="banner.close"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
