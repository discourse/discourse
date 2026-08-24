import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";
import { and, eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { tagNames, tagSuggestionParams } from "../lib/ai-helper-suggestions";
import { showComposerAiHelper } from "../lib/show-ai-helper";
import AiBlinkingAnimation from "./ai-blinking-animation";
import AiIndicatorWave from "./ai-indicator-wave";

const SUMMARY_DETAIL_VALUES = ["quiet", "balanced", "detailed"];

async function requestSuggestion(url, data) {
  try {
    return await ajax(url, { type: "POST", data });
  } catch {
    return null;
  }
}

async function enrichNewTopic({
  model,
  query,
  suggestTitle,
  suggestTaxonomy,
  canTagTopics,
  maxTitleLength,
}) {
  const initialTitle = model.title;
  const initialCategoryId = model.categoryId;
  const initialTags = tagNames(model.tags);
  const titleRequest = suggestTitle
    ? requestSuggestion("/discourse-ai/ai-helper/suggest_title", {
        text: query,
      })
    : null;
  const categoryRequest = suggestTaxonomy
    ? requestSuggestion("/discourse-ai/ai-helper/suggest_category", {
        text: query,
      })
    : null;
  const [titleResult, categoryResult] = await Promise.all([
    titleRequest,
    categoryRequest,
  ]);

  const suggestedTitle = titleResult?.suggestions?.[0]?.trim();
  if (suggestedTitle && model.title === initialTitle) {
    model.set("title", suggestedTitle.slice(0, maxTitleLength));
  }

  const suggestedCategory = categoryResult?.assistant?.[0];
  if (suggestedCategory && model.categoryId === initialCategoryId) {
    model.set("categoryId", suggestedCategory.id);
  }

  if (
    !suggestTaxonomy ||
    !canTagTopics ||
    tagNames(model.tags).join("\0") !== initialTags.join("\0")
  ) {
    return;
  }

  const tagResult = await requestSuggestion(
    "/discourse-ai/ai-helper/suggest_tags",
    {
      text: query,
      ...tagSuggestionParams(model.categoryId, model.tags),
    }
  );
  const suggestedTags = tagResult?.assistant
    ?.map((tag) => tag.name)
    .filter(Boolean);

  if (
    suggestedTags?.length &&
    tagNames(model.tags).join("\0") === initialTags.join("\0")
  ) {
    model.set("tags", suggestedTags);
  }
}

export default class AiSearchDiscoveries extends Component {
  @service search;
  @service messageBus;
  @service discobotDiscoveries;
  @service appEvents;
  @service currentUser;
  @service siteSettings;
  @service composer;

  @tracked loadingConversationTopic = false;
  @tracked followUpQuestion = "";

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
    return (
      this.args?.searchTerm ||
      this.search.activeGlobalSearchTerm ||
      ""
    ).trim();
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

  get showSummary() {
    return this.discobotDiscoveries.showSummary !== false;
  }

  get showAnswerTitle() {
    return this.showSummary && this.discobotDiscoveries.summaryDetail !== 0;
  }

  get relatedCount() {
    const count = this.discobotDiscoveries.relatedCount;
    return count >= 2 && count <= 6 ? count : 2;
  }

  get visibleSources() {
    return this.sources.slice(0, this.relatedCount);
  }

  get summaryDetails() {
    return [
      {
        value: "quiet",
        label: i18n("discourse_ai.discobot_discoveries.preferences.quiet"),
        disabled: !this.showSummary,
      },
      {
        value: "balanced",
        label: i18n("discourse_ai.discobot_discoveries.preferences.balanced"),
        disabled: !this.showSummary,
      },
      {
        value: "detailed",
        label: i18n("discourse_ai.discobot_discoveries.preferences.detailed"),
        disabled: !this.showSummary,
      },
    ];
  }

  get summaryDetailValue() {
    return (
      SUMMARY_DETAIL_VALUES[this.discobotDiscoveries.summaryDetail] ??
      "balanced"
    );
  }

  get fullSearchUrl() {
    return getURL(`/search?q=${encodeURIComponent(this.query)}`);
  }

  get canContinueConversation() {
    const agents = this.currentUser?.ai_enabled_agents;
    if (!this.siteSettings.ai_bot_enabled || !agents) {
      return false;
    }

    if (this.discobotDiscoveries.discoveryTimedOut) {
      return false;
    }

    const followUpAgent = agents.find(
      (agent) =>
        agent.id ===
        parseInt(this.siteSettings?.ai_discover_follow_up_agent, 10)
    );
    const hasEnabledLlmBot = this.currentUser.ai_enabled_chat_bots?.some(
      (bot) => !bot.is_agent && bot.username
    );
    const hasConversationRecipient = followUpAgent?.force_default_llm
      ? followUpAgent.username
      : hasEnabledLlmBot || followUpAgent?.username;
    const followUpAgentCanReceiveMessages =
      followUpAgent?.allow_personal_messages && hasConversationRecipient;

    return (
      (this.discobotDiscoveries.discovery?.length > 0 || this.hasSources) &&
      !this.discobotDiscoveries.isStreaming &&
      followUpAgentCanReceiveMessages
    );
  }

  get canSubmitFollowUp() {
    return this.followUpQuestion.trim().length > 0;
  }

  get continueConvoBtnLabel() {
    if (this.loadingConversationTopic) {
      return "discourse_ai.discobot_discoveries.loading_convo";
    }

    return "discourse_ai.discobot_discoveries.follow_up.submit";
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
  decreaseRelatedCount() {
    this.discobotDiscoveries.setRelatedCount(
      this.discobotDiscoveries.relatedCount - 1
    );
  }

  @action
  increaseRelatedCount() {
    this.discobotDiscoveries.setRelatedCount(
      this.discobotDiscoveries.relatedCount + 1
    );
  }

  @action
  toggleSummary() {
    this.discobotDiscoveries.setShowSummary(!this.showSummary);
  }

  @action
  selectSummaryDetail(detail) {
    const value = SUMMARY_DETAIL_VALUES.indexOf(detail);
    if (value !== -1) {
      this.discobotDiscoveries.setSummaryDetail(value);
    }
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
  updateFollowUpQuestion(event) {
    this.followUpQuestion = event.target.value;
  }

  @action
  async continueConversation(event) {
    event?.preventDefault();
    const question = this.followUpQuestion.trim();
    if (!question || this.loadingConversationTopic) {
      return;
    }

    const data = {
      request_id: this.discobotDiscoveries.activeRequestId,
      question,
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

      DiscourseURL.routeTo(`/t/${continueRequest.topic_id}`, {
        afterRouteComplete: () => {
          if (this.args.closeSearchMenu) {
            this.args.closeSearchMenu();
          }
        },
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingConversationTopic = false;
    }
  }

  @action
  async createTopic() {
    if (this.args.closeSearchMenu) {
      this.args.closeSearchMenu();
    }

    await this.composer.openNewTopic({ title: this.query });

    const model = this.composer.model;
    const suggestionsEnabled = showComposerAiHelper(
      model,
      this.siteSettings,
      this.currentUser,
      "suggestions"
    );

    await enrichNewTopic({
      model,
      query: this.query,
      suggestTitle: suggestionsEnabled,
      suggestTaxonomy:
        suggestionsEnabled && this.siteSettings.ai_embeddings_enabled,
      canTagTopics: this.currentUser.can_tag_topics,
      maxTitleLength: this.siteSettings.max_topic_title_length,
    });
  }

  <template>
    <div
      class={{dConcatClass
        "ai-search-discoveries"
        (if @fullPage "--full-page")
      }}
      {{didInsert this.subscribe this.query}}
      {{didUpdate this.subscribe this.query}}
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
            <div class="ai-discovery-preferences-menu">
              <DMenu
                @identifier="ai-discovery-preferences"
                @icon="ellipsis"
                @ariaLabel={{i18n
                  "discourse_ai.discobot_discoveries.preferences.label"
                }}
                @placement="bottom-end"
                @triggerClass="btn-flat ai-discovery-preferences-menu__trigger"
              >
                <:content>
                  <div class="ai-discovery-preferences">
                    <div class="ai-discovery-preferences__row">
                      <span class="ai-discovery-preferences__label">
                        {{i18n
                          "discourse_ai.discobot_discoveries.preferences.related_discussions"
                        }}
                      </span>
                      <div class="ai-discovery-preferences__stepper">
                        <DButton
                          class="btn-flat ai-discovery-preferences__decrement"
                          @icon="minus"
                          @translatedTitle={{i18n
                            "discourse_ai.discobot_discoveries.preferences.show_fewer_discussions"
                          }}
                          @disabled={{or
                            this.discobotDiscoveries.savingPreferences
                            (eq this.discobotDiscoveries.relatedCount 2)
                          }}
                          @action={{this.decreaseRelatedCount}}
                        />
                        <span class="ai-discovery-preferences__count">
                          {{this.discobotDiscoveries.relatedCount}}
                        </span>
                        <DButton
                          class="btn-flat ai-discovery-preferences__increment"
                          @icon="plus"
                          @translatedTitle={{i18n
                            "discourse_ai.discobot_discoveries.preferences.show_more_discussions"
                          }}
                          @disabled={{or
                            this.discobotDiscoveries.savingPreferences
                            (eq this.discobotDiscoveries.relatedCount 6)
                          }}
                          @action={{this.increaseRelatedCount}}
                        />
                      </div>
                    </div>

                    <div class="ai-discovery-preferences__summary-row">
                      <span class="ai-discovery-preferences__label">
                        {{i18n
                          "discourse_ai.discobot_discoveries.preferences.show_summary"
                        }}
                      </span>
                      <DToggleSwitch
                        class="ai-discovery-preferences__summary-toggle"
                        @state={{this.showSummary}}
                        aria-label={{i18n
                          "discourse_ai.discobot_discoveries.preferences.show_summary"
                        }}
                        disabled={{this.discobotDiscoveries.savingPreferences}}
                        {{on "click" this.toggleSummary}}
                      />
                    </div>

                    <div class="ai-discovery-preferences__detail-group">
                      <span
                        class="ai-discovery-preferences__label"
                        aria-hidden="true"
                      >
                        {{i18n
                          "discourse_ai.discobot_discoveries.preferences.summary_detail"
                        }}
                      </span>
                      <DSegmentedControl
                        class="ai-discovery-preferences__detail"
                        @name="ai-discovery-summary-detail"
                        @items={{this.summaryDetails}}
                        @value={{this.summaryDetailValue}}
                        @onSelect={{this.selectSummaryDetail}}
                        @translatedLabel={{i18n
                          "discourse_ai.discobot_discoveries.preferences.summary_detail"
                        }}
                      />
                      <p class="ai-discovery-preferences__hint">
                        {{i18n
                          (concat
                            "discourse_ai.discobot_discoveries.preferences.detail_hint_"
                            this.discobotDiscoveries.summaryDetail
                          )
                        }}
                      </p>
                    </div>
                  </div>
                </:content>
              </DMenu>
            </div>
          </header>
        {{/if}}
      {{/if}}

      {{#if (and this.showAnswerTitle this.discobotDiscoveries.discoveryTitle)}}
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
          <div class="ai-search-discoveries__no-answer">
            <p class="ai-search-discoveries__no-answer-message">
              {{i18n "discourse_ai.discobot_discoveries.no_answer"}}
            </p>
            {{#if this.currentUser.can_create_topic}}
              <DButton
                @label="discourse_ai.discobot_discoveries.create_topic"
                @action={{this.createTopic}}
                class="btn-primary btn-small ai-search-discoveries__create-topic"
              />
            {{/if}}
          </div>
        {{else if this.showSummary}}
          {{! eslint-disable ember/template-no-invalid-interactive }}
          <article
            class={{dConcatClass
              "ai-search-discoveries__discovery"
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
                      <h5
                        class="ai-discovery-source__title"
                      >{{source.title}}</h5>
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
                          {{i18n
                            "replies_lowercase"
                            count=source.topic_replies
                          }}
                        </span>
                      </span>
                    </span>
                  </a>
                </li>
              {{/each}}
            </ul>
          </section>
        {{/if}}
      {{/if}}

      {{#if this.canContinueConversation}}
        <form
          class="ai-search-discoveries__continue-conversation"
          {{on "submit" this.continueConversation}}
        >
          <input
            class="ai-search-discoveries__follow-up-input"
            type="text"
            value={{this.followUpQuestion}}
            maxlength="1000"
            placeholder={{i18n
              "discourse_ai.discobot_discoveries.follow_up.placeholder"
            }}
            aria-label={{i18n
              "discourse_ai.discobot_discoveries.follow_up.label"
            }}
            disabled={{this.loadingConversationTopic}}
            {{on "input" this.updateFollowUpQuestion}}
          />
          <DButton
            @type="submit"
            @label={{this.continueConvoBtnLabel}}
            @disabled={{or
              this.loadingConversationTopic
              (not this.canSubmitFollowUp)
            }}
            class="btn-primary btn-small ai-search-discoveries__follow-up-submit"
          >
            <AiIndicatorWave @loading={{this.loadingConversationTopic}} />
          </DButton>
        </form>
      {{/if}}
    </div>
  </template>
}
