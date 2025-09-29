import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";
import AiBlinkingAnimation from "./ai-blinking-animation";
import AiIndicatorWave from "./ai-indicator-wave";

export default class AiSearchDiscoveries extends Component {
  @service search;
  @service messageBus;
  @service discobotDiscoveries;
  @service appEvents;
  @service currentUser;
  @service siteSettings;
  @service composer;

  @tracked loadingConversationTopic = false;
  @tracked fullDiscoveryToggled = false;
  @tracked discoveryPreviewLength = this.args.discoveryPreviewLength || 150;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "full-page-search:trigger-search",
      this,
      this.triggerDiscovery
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "full-page-search:trigger-search",
      this,
      this.triggerDiscovery
    );
  }

  @bind
  async _updateDiscovery(update) {
    if (this.query === update.query) {
      this.discobotDiscoveries.onDiscoveryUpdate(update);
    }
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(
      "/discourse-ai/discoveries",
      this._updateDiscovery
    );
  }

  @bind
  subscribe() {
    this.messageBus.subscribe(
      "/discourse-ai/discoveries",
      this._updateDiscovery
    );
  }

  get query() {
    return this.args?.searchTerm || this.search.activeGlobalSearchTerm;
  }

  get toggleLabel() {
    if (this.fullDiscoveryToggled) {
      return "discourse_ai.discobot_discoveries.collapse";
    } else {
      return "discourse_ai.discobot_discoveries.tell_me_more";
    }
  }

  get toggleIcon() {
    if (this.fullDiscoveryToggled) {
      return "chevron-up";
    } else {
      return "";
    }
  }

  get canShowExpandtoggle() {
    return (
      !this.discobotDiscoveries.loadingDiscoveries &&
      this.discobotDiscoveries.streamedText.length > this.discoveryPreviewLength
    );
  }

  get renderPreviewOnly() {
    return !this.fullDiscoveryToggled && this.canShowExpandtoggle;
  }

  get canContinueConversation() {
    const personas = this.currentUser?.ai_enabled_personas;
    if (!personas) {
      return false;
    }

    if (this.discobotDiscoveries.discoveryTimedOut) {
      return false;
    }

    const discoverPersona = personas.find(
      (persona) =>
        persona.id === parseInt(this.siteSettings?.ai_discover_persona, 10)
    );
    const discoverPersonaHasBot = discoverPersona?.username;

    return (
      this.discobotDiscoveries.discovery?.length > 0 &&
      !this.discobotDiscoveries.isStreaming &&
      discoverPersonaHasBot
    );
  }

  get continueConvoBtnLabel() {
    if (this.loadingConversationTopic) {
      return "discourse_ai.discobot_discoveries.loading_convo";
    }

    return "discourse_ai.discobot_discoveries.continue_convo";
  }

  @action
  async triggerDiscovery() {
    this.discobotDiscoveries.triggerDiscovery(this.query);
  }

  @action
  toggleDiscovery() {
    this.fullDiscoveryToggled = !this.fullDiscoveryToggled;
  }

  @action
  async continueConversation() {
    const data = {
      user_id: this.currentUser.id,
      query: this.query,
      context: this.discobotDiscoveries.discovery,
    };
    try {
      this.loadingConversationTopic = true;
      const continueRequest = await ajax(
        `/discourse-ai/discoveries/continue-convo`,
        {
          type: "POST",
          data,
        }
      );
      const topicJSON = await Topic.find(continueRequest.topic_id, {});
      const topic = Topic.create(topicJSON);

      DiscourseURL.routeTo(`/t/${continueRequest.topic_id}`, {
        afterRouteComplete: () => {
          if (this.args.closeSearchMenu) {
            this.args.closeSearchMenu();
          }

          this.composer.focusComposer({
            topic,
          });
        },
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingConversationTopic = false;
    }
  }

  <template>
    <div
      class="ai-search-discoveries"
      {{didInsert this.subscribe this.query}}
      {{didUpdate this.subscribe this.query}}
      {{didInsert this.triggerDiscovery this.query}}
      {{willDestroy this.unsubscribe}}
    >
      <div class="ai-search-discoveries__completion">
        {{#if this.discobotDiscoveries.loadingDiscoveries}}
          <AiBlinkingAnimation />
        {{else if this.discobotDiscoveries.discoveryTimedOut}}
          {{i18n "discourse_ai.discobot_discoveries.timed_out"}}
        {{else}}
          <article
            class={{concatClass
              "ai-search-discoveries__discovery"
              (if this.renderPreviewOnly "preview")
              (if this.discobotDiscoveries.isStreaming "streaming")
              "streamable-content"
            }}
          >
            <CookText
              @rawText={{this.discobotDiscoveries.streamedText}}
              class="cooked"
            />
          </article>

          {{#if this.canShowExpandtoggle}}
            <DButton
              class="btn-flat btn-text ai-search-discoveries__toggle"
              @label={{this.toggleLabel}}
              @icon={{this.toggleIcon}}
              @action={{this.toggleDiscovery}}
            />
          {{/if}}
        {{/if}}
      </div>

      {{#if this.canContinueConversation}}
        <div class="ai-search-discoveries__continue-conversation">
          <DButton
            @action={{this.continueConversation}}
            @label={{this.continueConvoBtnLabel}}
            class="btn-default btn-small"
          >
            <AiIndicatorWave @loading={{this.loadingConversationTopic}} />
          </DButton>
        </div>
      {{/if}}
    </div>
  </template>
}
