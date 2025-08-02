import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DiscourseLinkedText from "discourse/components/discourse-linked-text";

const USER_DISMISSED_PROMPT_KEY = "dismissed-pwa-install-banner";

export default class PwaInstallBanner extends Component {
  @service capabilities;
  @service currentUser;
  @service keyValueStore;
  @service siteSettings;

  @tracked
  bannerDismissed =
    this.keyValueStore.get(USER_DISMISSED_PROMPT_KEY) === "true";

  @tracked deferredInstallPromptEvent = null;

  registerInstallPromptListener = modifierFn(() => {
    const handler = (event) => {
      // Prevent Chrome 76+ from automatically showing the prompt
      event.preventDefault();
      // Stash the event so it can be triggered later
      this.deferredInstallPromptEvent = event;
    };

    window.addEventListener("beforeinstallprompt", handler);

    return () => {
      window.removeEventListener("beforeinstallprompt", handler);
    };
  });

  get showPWAInstallBanner() {
    return (
      this.capabilities.isAndroid &&
      this.currentUser?.trust_level > 0 &&
      this.deferredInstallPromptEvent && // Pass the browser engagement checks
      !window.matchMedia("(display-mode: standalone)").matches && // Not be in the installed PWA already
      !this.capabilities.isAppWebview && // not launched via official app
      !this.bannerDismissed // Have not a previously dismissed install banner
    );
  }

  @action
  turnOn() {
    this.dismiss();
    this.deferredInstallPromptEvent.prompt();
  }

  @action
  dismiss() {
    this.keyValueStore.set({ key: USER_DISMISSED_PROMPT_KEY, value: true });
    this.bannerDismissed = true;
  }

  <template>
    {{#if this.showPWAInstallBanner}}
      <div class="pwa-install-banner alert alert-info">
        <span>
          <DiscourseLinkedText
            @action={{this.turnOn}}
            @text="pwa.install_banner"
            @textParams={{hash title=this.siteSettings.title}}
          />
        </span>
        <DButton
          @icon="xmark"
          @action={{this.dismiss}}
          @title="banner.close"
          class="btn-transparent close"
        />
      </div>
    {{/if}}
  </template>
}
