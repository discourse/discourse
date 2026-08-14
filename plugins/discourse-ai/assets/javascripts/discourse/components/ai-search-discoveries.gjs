import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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
  @tracked showAllSources = false;

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

  get discoveryPreviewLength() {
    return this.args.discoveryPreviewLength || 150;
  }

  get query() {
    return (
      this.args?.searchTerm ||
      this.search.activeGlobalSearchTerm ||
      ""
    ).trim();
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
      this.args.collapsible !== false &&
      !this.discobotDiscoveries.loadingDiscoveries &&
      this.discobotDiscoveries.streamedText.length > this.discoveryPreviewLength
    );
  }

  get renderPreviewOnly() {
    return !this.fullDiscoveryToggled && this.canShowExpandtoggle;
  }

  get sources() {
    return this.discobotDiscoveries.sources || [];
  }

  get hasSources() {
    return this.sources.length > 0;
  }

  get noAnswer() {
    return this.discobotDiscoveries.answerable === false;
  }

  get visibleSources() {
    return this.showAllSources ? this.sources : this.sources.slice(0, 2);
  }

  get canToggleSources() {
    return this.sources.length > 2;
  }

  get sourceToggleLabel() {
    if (this.showAllSources) {
      return i18n("discourse_ai.discobot_discoveries.sources.show_fewer");
    }

    return i18n("discourse_ai.discobot_discoveries.sources.view_all", {
      count: this.sources.length,
    });
  }

  get fullSearchUrl() {
    return getURL(`/search?q=${encodeURIComponent(this.query)}`);
  }

  get canContinueConversation() {
    const agents = this.currentUser?.ai_enabled_agents;
    if (!agents) {
      return false;
    }

    if (this.discobotDiscoveries.discoveryTimedOut) {
      return false;
    }

    const discoverAgent = agents.find(
      (agent) => agent.id === parseInt(this.siteSettings?.ai_discover_agent, 10)
    );
    const discoverAgentHasBot = discoverAgent?.username;

    return (
      this.discobotDiscoveries.discovery?.length > 0 &&
      !this.discobotDiscoveries.isStreaming &&
      discoverAgentHasBot
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
  triggerDiscoveryOnInsert() {
    if (this.args.triggerOnInsert !== false) {
      this.triggerDiscovery();
    }
  }

  @action
  toggleDiscovery() {
    this.fullDiscoveryToggled = !this.fullDiscoveryToggled;
  }

  @action
  toggleSources() {
    this.showAllSources = !this.showAllSources;
  }

  @action
  resetSourceExpansion() {
    this.showAllSources = false;
  }

  @action
  handleDiscoveryClick(event) {
    const target = event.target;
    const link = target.closest("a");

    if (!link) {
      return;
    }

    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    DiscourseURL.routeTo(link.href);

    if (this.args.closeSearchMenu) {
      this.args.closeSearchMenu();
    }
  }

  @action
  async continueConversation() {
    const data = {
      request_id: this.discobotDiscoveries.activeRequestId,
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
      class={{dConcatClass
        "ai-search-discoveries"
        (if @fullPage "--full-page")
      }}
      {{didInsert this.subscribe this.query}}
      {{didUpdate this.subscribe this.query}}
      {{didUpdate this.resetSourceExpansion this.query}}
      {{didInsert this.triggerDiscoveryOnInsert this.query}}
      {{willDestroy this.unsubscribe}}
    >
      {{#if @showHeading}}
        {{#if this.discobotDiscoveries.showDiscoveryTitle}}
          <header class="ai-search-discoveries__header">
            <h3 class="ai-search-discoveries__title">
              {{dIcon "far-circle"}}
              {{i18n "discourse_ai.discobot_discoveries.main_title"}}
            </h3>
          </header>
        {{/if}}
      {{/if}}

      {{#if this.discobotDiscoveries.discoveryTitle}}
        <h4 class="ai-search-discoveries__answer-title">
          {{this.discobotDiscoveries.discoveryTitle}}
        </h4>
      {{/if}}

      <div class="ai-search-discoveries__completion">
        {{#if this.discobotDiscoveries.loadingDiscoveries}}
          <AiBlinkingAnimation />
        {{else if this.discobotDiscoveries.errorMessage}}
          <p class="ai-search-discoveries__error">
            {{this.discobotDiscoveries.errorMessage}}
          </p>
        {{else if this.discobotDiscoveries.discoveryTimedOut}}
          {{i18n "discourse_ai.discobot_discoveries.timed_out"}}
        {{else if this.noAnswer}}
          <p class="ai-search-discoveries__no-answer">
            {{i18n "discourse_ai.discobot_discoveries.no_answer"}}
          </p>
        {{else}}
          {{! eslint-disable ember/template-no-invalid-interactive }}
          <article
            class={{dConcatClass
              "ai-search-discoveries__discovery"
              (if this.renderPreviewOnly "preview")
              (if this.discobotDiscoveries.isStreaming "streaming")
              "streamable-content"
            }}
            {{on "click" this.handleDiscoveryClick}}
          >
            <DCookText
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

      {{#if @showSources}}
        {{#if this.hasSources}}
          <section
            class="ai-discovery-sources"
            aria-labelledby="ai-discovery-sources-title"
          >
            <header class="ai-discovery-sources__header">
              <h4
                id="ai-discovery-sources-title"
                class="ai-discovery-sources__title"
              >
                {{i18n
                  "discourse_ai.discobot_discoveries.sources.related_discussions"
                }}
              </h4>
              {{#if this.canToggleSources}}
                <DButton
                  class="ai-discovery-sources__toggle"
                  @display="link"
                  @translatedLabel={{this.sourceToggleLabel}}
                  @ariaExpanded={{this.showAllSources}}
                  @action={{this.toggleSources}}
                />
              {{/if}}
            </header>

            <ul
              class="ai-discovery-sources__list"
              {{on "click" this.handleDiscoveryClick}}
            >
              {{#each this.visibleSources as |source|}}
                <li class="ai-discovery-sources__item">
                  <a class="ai-discovery-source" href={{source.url}}>
                    {{#if source.avatar_template}}
                      <span class="ai-discovery-source__avatar">
                        {{dAvatar source imageSize="medium"}}
                      </span>
                    {{/if}}
                    <span class="ai-discovery-source__content">
                      <h5 class="ai-discovery-source__title">{{source.title}}</h5>
                      {{#if source.excerpt}}
                        <span class="ai-discovery-source__excerpt">
                          {{source.excerpt}}
                        </span>
                      {{/if}}
                      <span class="ai-discovery-source__metadata">
                        {{#if source.category}}
                          <span>{{source.category}}</span>
                          <span aria-hidden="true">·</span>
                        {{/if}}
                        <span>
                          {{source.topic_replies}}
                          {{i18n "replies_lowercase" count=source.topic_replies}}
                        </span>
                      </span>
                    </span>
                  </a>
                </li>
              {{/each}}
            </ul>

            <a
              class="ai-discovery-sources__all-results"
              href={{this.fullSearchUrl}}
              {{on "click" this.handleDiscoveryClick}}
            >
              {{i18n
                "discourse_ai.discobot_discoveries.sources.show_all_matching"
              }}
              {{dIcon "arrow-right"}}
            </a>
          </section>
        {{/if}}
      {{/if}}

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
