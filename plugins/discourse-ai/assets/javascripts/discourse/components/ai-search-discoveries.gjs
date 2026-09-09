import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { tagNames, tagSuggestionParams } from "../lib/ai-helper-suggestions";
import { showComposerAiHelper } from "../lib/show-ai-helper";
import AiBlinkingAnimation from "./ai-blinking-animation";
import AiIndicatorWave from "./ai-indicator-wave";

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
  @service keyValueStore;
  @service toasts;
  @service site;
  @service siteSettings;
  @service composer;

  @tracked loadingConversationTopic = false;
  @tracked followUpQuestion = "";
  @tracked followUpTouched = null;
  @tracked dismissedAskAiDefault = false;

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

  get query() {
    return (
      this.args?.searchTerm ||
      this.search.activeGlobalSearchTerm ||
      ""
    ).trim();
  }

  // Off unless a theme has room for it: the list is dense and the avatar is
  // decoration rather than a way to tell the sources apart.
  get showSourceAvatars() {
    return applyValueTransformer("ai-discovery-source-avatar", false);
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

  // Every branch of the completion puts something on screen except the last,
  // which is an empty article until the first text streams in. Marking that
  // gap lets it be styled away rather than showing as blank space.
  get hasNoContent() {
    const discoveries = this.discobotDiscoveries;

    return (
      !discoveries.loadingDiscoveries &&
      !discoveries.errorMessage &&
      !discoveries.discoveryTimedOut &&
      !this.noAnswer &&
      !discoveries.streamedText
    );
  }

  get showAnswerTitle() {
    return this.siteSettings.ai_ask_ai_summary_detail !== "quiet";
  }

  get relatedCount() {
    return this.siteSettings.ai_ask_ai_related_count;
  }

  get visibleSources() {
    return this.sources.slice(0, this.relatedCount).map((source) => ({
      ...source,
      // the payload carries a breadcrumb string for the model; the badge needs
      // the real category so it picks up its colour, style and parent
      categoryModel: this.site.categories?.find(
        (category) => category.id === source.category_id
      ),
    }));
  }

  get candidateTopicIds() {
    return this.discobotDiscoveries.candidateTopicIds || [];
  }

  get hasMatchingTopics() {
    return this.candidateTopicIds.length > 0;
  }

  get fullSearchUrl() {
    const topicFilter = `topic:${this.candidateTopicIds.join(",")}`;
    return getURL(`/filter?q=${encodeURIComponent(topicFilter)}`);
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
        agent.id === parseInt(this.siteSettings?.ai_ask_ai_follow_up_agent, 10)
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

  get followUpValue() {
    // The touch belongs to the answer it was made against: a later answer
    // brings its own suggestion, which should be offered rather than suppressed
    // because the reader once typed over an earlier one.
    if (this.followUpTouched === this.discobotDiscoveries.suggestedFollowUp) {
      return this.followUpQuestion;
    }

    return this.discobotDiscoveries.suggestedFollowUp || "";
  }

  get showAskAiDefaultToggle() {
    return (
      Boolean(this.currentUser) &&
      !this.hasNoContent &&
      !this.askAiDefaultDismissed
    );
  }

  get askAiIsDefault() {
    return Boolean(get(this.currentUser, "user_option.ai_ask_ai_default"));
  }

  get canSubmitFollowUp() {
    return this.followUpValue.trim().length > 0;
  }

  get continueConvoBtnLabel() {
    if (this.loadingConversationTopic) {
      return "discourse_ai.discobot_discoveries.loading_convo";
    }

    return "discourse_ai.discobot_discoveries.follow_up.submit";
  }

  get askAiDefaultDismissKey() {
    return `ask-ai-default-dismissed-${this.currentUser?.id}`;
  }

  get askAiDefaultDismissed() {
    // the stored value is not tracked, so the dismissal this session is what
    // takes the control off screen without waiting for a reload
    return (
      this.dismissedAskAiDefault ||
      Boolean(this.keyValueStore.get(this.askAiDefaultDismissKey))
    );
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
  dismissAskAiDefaultToggle() {
    this.keyValueStore.setItem(this.askAiDefaultDismissKey, "true");
    this.dismissedAskAiDefault = true;

    this.toasts.success({
      data: {
        message: i18n(
          "discourse_ai.discobot_discoveries.default_preference_dismissed"
        ),
      },
    });
  }

  @action
  async toggleAskAiDefault() {
    const wanted = !this.askAiIsDefault;
    this.currentUser.set("user_option.ai_ask_ai_default", wanted);

    try {
      await ajax(`/u/${this.currentUser.username}.json`, {
        type: "PUT",
        data: { ai_ask_ai_default: wanted },
      });
    } catch (error) {
      this.currentUser.set("user_option.ai_ask_ai_default", !wanted);
      popupAjaxError(error);
    }
  }

  @action
  updateFollowUpQuestion(event) {
    this.followUpTouched = this.discobotDiscoveries.suggestedFollowUp;
    this.followUpQuestion = event.target.value;
  }

  // Focus is the point at which the reader has decided to ask something of
  // their own, so the offered question gets out of the way rather than being
  // text they have to delete.
  @action
  clearSuggestedFollowUp() {
    if (this.followUpTouched === this.discobotDiscoveries.suggestedFollowUp) {
      return;
    }

    this.followUpTouched = this.discobotDiscoveries.suggestedFollowUp;
    this.followUpQuestion = "";
  }

  @action
  async continueConversation(event) {
    event?.preventDefault();
    const question = this.followUpValue.trim();
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

  @bind
  async _updateDiscovery(update) {
    if (this.query === update.query) {
      this.discobotDiscoveries.onDiscoveryUpdate(update);
    }
  }

  <template>
    <div
      class={{dConcatClass
        "ai-search-discoveries"
        (if @fullPage "--full-page")
        (if this.hasNoContent "--empty")
      }}
      {{didInsert this.subscribe this.query}}
      {{didUpdate this.subscribe this.query}}
      {{didInsert this.triggerDiscoveryOnInsert this.query}}
      {{willDestroy this.unsubscribe}}
    >

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
                class="btn-primary btn-small ai-search-discoveries__create-topic"
                @action={{this.createTopic}}
                @label="discourse_ai.discobot_discoveries.create_topic"
              />
            {{/if}}
          </div>
        {{else}}
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
              class="cooked"
              @rawText={{this.discobotDiscoveries.streamedText}}
            />
          </article>

        {{/if}}
      </div>

      {{#if @showSources}}
        {{#if this.hasSources}}
          <section
            aria-labelledby="ai-discovery-sources-title"
            class="ai-discovery-sources"
          >
            <header class="ai-discovery-sources__header">
              <h4
                class="ai-discovery-sources__title"
                id="ai-discovery-sources-title"
              >
                {{i18n
                  "discourse_ai.discobot_discoveries.sources.related_discussions"
                }}
              </h4>
              {{#if this.hasMatchingTopics}}
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
              {{/if}}
            </header>

            <ul
              class="ai-discovery-sources__list"
              {{on "click" this.handleDiscoveryClick}}
            >
              {{#each this.visibleSources as |source|}}
                <li class="ai-discovery-sources__item">
                  <a class="ai-discovery-source" href={{source.url}}>
                    {{#if (and this.showSourceAvatars source.avatar_template)}}
                      <span class="ai-discovery-source__avatar">
                        {{dAvatar source imageSize="medium"}}
                      </span>
                    {{/if}}
                    <span class="ai-discovery-source__content">
                      <h5 class="ai-discovery-source__title">{{dReplaceEmoji
                          source.title
                        }}</h5>
                      {{#if source.excerpt}}
                        <span class="ai-discovery-source__excerpt">
                          {{dReplaceEmoji source.excerpt}}
                        </span>
                      {{/if}}
                      <span class="ai-discovery-source__metadata">
                        {{#if source.categoryModel}}
                          {{dCategoryLink source.categoryModel link=false}}
                        {{/if}}
                        {{#if source.topic_replies}}
                          <span class="ai-discovery-source__metadata-replies">
                            {{dIcon "reply"}}
                            {{source.topic_replies}}
                            {{i18n
                              "replies_lowercase"
                              count=source.topic_replies
                            }}
                          </span>
                        {{/if}}
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
            aria-label={{i18n
              "discourse_ai.discobot_discoveries.follow_up.label"
            }}
            class="ai-search-discoveries__follow-up-input"
            disabled={{this.loadingConversationTopic}}
            maxlength="1000"
            placeholder={{i18n
              "discourse_ai.discobot_discoveries.follow_up.placeholder"
            }}
            type="text"
            value={{this.followUpValue}}
            {{on "focus" this.clearSuggestedFollowUp}}
            {{on "input" this.updateFollowUpQuestion}}
          />
          <DButton
            class="btn-primary btn-small ai-search-discoveries__follow-up-submit"
            @disabled={{or
              this.loadingConversationTopic
              (not this.canSubmitFollowUp)
            }}
            @label={{this.continueConvoBtnLabel}}
            @type="submit"
          >
            <AiIndicatorWave @loading={{this.loadingConversationTopic}} />
          </DButton>
        </form>
      {{/if}}

      {{#if this.showAskAiDefaultToggle}}
        <div class="ai-search-discoveries__default-preference">
          <DToggleSwitch
            class="ai-search-discoveries__default-toggle"
            @label="discourse_ai.discobot_discoveries.make_default"
            @state={{this.askAiIsDefault}}
            {{on "click" this.toggleAskAiDefault}}
          />
          <DButton
            class="btn-transparent ai-search-discoveries__dismiss-default"
            @action={{this.dismissAskAiDefaultToggle}}
            @icon="xmark"
            @title="discourse_ai.discobot_discoveries.dismiss_default_preference"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
