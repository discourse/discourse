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

    const storedValue = pushNotificationKeyValueStore.getItem(
      userDismissedPromptKey
    );

    const parsedValue = parseInt(storedValue, 10);
    if (Number.isNaN(parsedValue)) {
      // This can only happen if the user dismissed this banner before we started storing a
      // timestamp in their local storage.
      // Just reset the dismissal state so they have the chance to dismiss this banner again.
      this.setBannerDismissed(false);
    }
  }

  setBannerDismissed(value) {
    if (value) {
      const timestamp = Date.now();
      pushNotificationKeyValueStore.setItem(userDismissedPromptKey, timestamp);
    } else {
      pushNotificationKeyValueStore.removeItem(userDismissedPromptKey);
    }

    this.bannerDismissed = pushNotificationKeyValueStore.getItem(
      userDismissedPromptKey
    ) != null;
  }

  get showNotificationPwaTip() {
    return this.desktopNotifications.isPushNotificationsPreferred &&
           this.desktopNotifications.isPushSupported &&
           this.desktopNotifications.isPushPwaNeeded;
  }

  get showNotificationPromptBanner() {
    let supported = false;
    if (this.desktopNotifications.isPushNotificationsPreferred) {
      // TODO: Eventually we want to show this banner even if a PWA is needed (and
      // guide users toward adding the app to their homescreen).
      supported = this.desktopNotifications.isPushSupported && !this.desktopNotifications.isPushPwaNeeded;
    } else {
      supported = this.desktopNotifications.isSupported;
    }

    return (
      !this.bannerDismissed &&
      this.siteSettings.push_notifications_prompt &&
      supported &&
      this.currentUser &&
      Notification.permission !== "denied" &&
      !this.desktopNotifications.isEnabled
    );
  }

  @action
  async turnon() {
    if (await this.desktopNotifications.enable()) {
      // Dismiss the banner iff notifications were successfully enabled.
      this.setBannerDismissed(true);
    } else {
      // TODO: Force a re-render to recheck our conditions. The below does not work for some reason.
      // this.rerender();
    }
  }

  @action
  dismiss() {
    this.setBannerDismissed(true);
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
