import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";

export default class SoftwareUpdatePrompt extends Component {
  @service messageBus;
  @service session;

  @tracked showPrompt = false;
  @tracked animatePrompt = false;
  timeoutHandler;

  constructor() {
    super(...arguments);

    this.messageBus.subscribe("/refresh_client", this.onRefresh);
    this.messageBus.subscribe("/global/asset-version", this.onAsset);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.messageBus.unsubscribe("/refresh_client", this.onRefresh);
    this.messageBus.unsubscribe("/global/asset-version", this.onAsset);

    cancel(this.timeoutHandler);
  }

  @bind
  onRefresh() {
    this.session.requiresRefresh = true;
  }

  @bind
  onAsset(version) {
    if (this.session.assetVersion !== version) {
      this.session.requiresRefresh = true;
    }

    if (!this.timeoutHandler && this.session.requiresRefresh) {
      if (isTesting()) {
        this.updatePromptState(true);
      } else {
        // Since we can do this transparently for people browsing the forum
        // hold back the message 24 hours.
        this.timeoutHandler = discourseLater(
          () => this.updatePromptState(true),
          1000 * 60 * 24 * 60
        );
      }
    }
  }

  updatePromptState(value) {
    // when adding the message, we inject the HTML then add the animation
    // when dismissing, things need to happen in the opposite order
    const firstProp = value ? "showPrompt" : "animatePrompt";
    const secondProp = value ? "animatePrompt" : "showPrompt";

    this[firstProp] = value;

    if (isTesting()) {
      this[secondProp] = value;
    } else {
      discourseLater(() => (this[secondProp] = value), 500);
    }
  }

  @action
  refreshPage() {
    document.location.reload();
  }

  @action
  dismiss() {
    this.updatePromptState(false);
  }

  <template>
    {{#if this.showPrompt}}
      <div
        class={{concatClass
          "software-update-prompt"
          (if this.animatePrompt "require-software-refresh")
        }}
      >
        <div class="wrap">
          <div aria-live="polite" class="update-prompt-main-content">
            <DButton
              @action={{this.refreshPage}}
              @icon="arrow-rotate-right"
              @label="software_update_prompt.message"
              class="btn-transparent update-prompt-message"
            />

            <span class="update-prompt-dismiss">
              <DButton
                @action={{this.dismiss}}
                @icon="xmark"
                aria-label={{i18n "software_update_prompt.dismiss"}}
                class="btn-transparent"
              />
            </span>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
