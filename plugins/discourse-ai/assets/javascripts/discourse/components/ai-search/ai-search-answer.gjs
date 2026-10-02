import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { openTopicFromQuery } from "../../lib/open-topic-from-query";

/**
 * The answer for the current combined search. It opens to its related topics
 * and a follow-up field, and asking a follow-up continues on the full page.
 */
export default class AiSearchAnswer extends Component {
  @service aiSearchSession;
  @service composer;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked followUpValue = "";
  @tracked startingConversation = false;

  get session() {
    return this.aiSearchSession;
  }

  get discoveries() {
    return this.session.discoveries;
  }

  get answerFailureMessage() {
    if (this.discoveries.errorMessage) {
      return this.discoveries.errorMessage;
    }
    if (this.discoveries.discoveryTimedOut) {
      return i18n("discourse_ai.discobot_discoveries.timed_out");
    }
    return i18n("discourse_ai.discobot_discoveries.no_answer");
  }

  // nothing in the forum answered it, so the next step is asking people
  get canAskCommunity() {
    return (
      this.discoveries.answerable === false &&
      Boolean(this.currentUser?.can_create_topic)
    );
  }

  get expanded() {
    return this.session.expanded;
  }

  // The box is short enough that an answer nearly always runs past it, and
  // related topics and the follow-up wait behind it too, so it is offered as
  // soon as the answer starts rather than appearing partway through.
  get hasMore() {
    return (
      this.expanded ||
      (!this.discoveries.loadingDiscoveries && !this.session.answerFailed)
    );
  }

  get showActions() {
    return this.hasMore || this.discoveries.loadingDiscoveries;
  }

  get suggestedFollowUp() {
    return this.discoveries.suggestedFollowUp || "";
  }

  @action
  async askCommunity(event) {
    event.preventDefault();
    this.args.onNavigate?.();
    await openTopicFromQuery({
      composer: this.composer,
      currentUser: this.currentUser,
      query: this.session.query,
      siteSettings: this.siteSettings,
    });
  }

  @action
  updateFollowUp(event) {
    this.followUpValue = event.target.value;
  }

  @action
  followLink(event) {
    if (event.target.closest("a")) {
      this.args.onNavigate?.();
    }
  }

  @action
  async startConversation(event) {
    event.preventDefault();
    const question = this.followUpValue.trim() || this.suggestedFollowUp;
    if (!question || this.startingConversation) {
      return;
    }

    this.startingConversation = true;
    try {
      const topicId = await this.session.startConversation(question);
      this.args.onNavigate?.();
      // the conversation keeps looking where the answer was found
      const scope = this.session.scopeFallback ? null : this.session.scope?.key;
      this.router.transitionTo("discourse-ai-search", {
        queryParams: { q: null, topic: topicId, scope: scope ?? null },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.startingConversation = false;
    }
  }

  <template>
    {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
    <section
      aria-busy={{unless this.session.answerSettled "true"}}
      aria-label={{i18n "discourse_ai.ai_search.answer_label"}}
      class={{dConcatClass
        "ai-search-answer"
        (if @compact "--compact")
        (if this.session.answerFailed "--no-answer")
        (if this.expanded "--expanded")
        (if this.hasMore "--has-more")
      }}
      {{on "click" this.followLink}}
    >
      <div class="ai-search-answer__body">
        <div class="ai-search-answer__content">
          {{#if
            (and
              this.session.scopeFallback
              this.session.fallbackScopeLabel
              (not this.session.answerFailed)
            )
          }}
            <p class="ai-search-answer__scope-note">
              {{i18n
                "discourse_ai.ai_search.scope.fallback"
                name=this.session.fallbackScopeLabel
              }}
            </p>
          {{/if}}
          {{#if this.discoveries.loadingDiscoveries}}
            <DSkeleton class="ai-search-answer__title-skeleton" @width="60%" />
            <DSkeleton @count={{2}} @lastLineWidth="45%" />
          {{else if this.canAskCommunity}}
            <p class="ai-search-answer__empty">
              <span>
                <DInterpolatedTranslation
                  @key="discourse_ai.ai_search.no_answer"
                  as |Placeholder|
                >
                  <Placeholder @name="askLink">
                    <a
                      class="ai-search-answer__ask-community"
                      href
                      {{on "click" this.askCommunity}}
                    >{{i18n "discourse_ai.ai_search.ask_community"}}</a>
                  </Placeholder>
                </DInterpolatedTranslation>
              </span>
            </p>
          {{else if this.session.answerFailed}}
            <p class="ai-search-answer__empty">{{this.answerFailureMessage}}</p>
          {{else}}
            {{#if this.discoveries.discoveryTitle}}
              <h3 class="ai-search-answer__title">
                {{this.discoveries.discoveryTitle}}
              </h3>
            {{/if}}
            <DCookText
              class={{dConcatClass
                "cooked"
                (if this.discoveries.isStreaming "streaming")
              }}
              @rawText={{this.discoveries.streamedText}}
            />
          {{/if}}
        </div>
      </div>

      {{#if this.expanded}}
        <div class="ai-search-answer__more">
          <ul class="ai-search-answer__related">
            {{#each this.session.relatedTopics as |topic|}}
              <li class="ai-search-answer__related-item">
                <a class="ai-search-answer__related-link" href={{topic.url}}>
                  <span class="ai-search-answer__related-title">
                    {{dReplaceEmoji topic.title}}
                  </span>
                  {{#if topic.excerpt}}
                    <span class="ai-search-answer__related-excerpt">
                      {{dReplaceEmoji topic.excerpt}}
                    </span>
                  {{/if}}
                  {{#if topic.categoryModel}}
                    {{dCategoryLink topic.categoryModel link=false}}
                  {{/if}}
                </a>
              </li>
            {{/each}}
          </ul>

          {{#if this.session.canFollowUp}}
            <form
              class="ai-search-answer__follow-up"
              {{on "submit" this.startConversation}}
            >
              <input
                aria-label={{i18n "discourse_ai.ai_search.follow_up_label"}}
                class="ai-search-answer__follow-up-input"
                maxlength="1000"
                placeholder={{if
                  this.suggestedFollowUp
                  this.suggestedFollowUp
                  (i18n "discourse_ai.ai_search.follow_up_placeholder")
                }}
                type="text"
                value={{this.followUpValue}}
                {{on "input" this.updateFollowUp}}
              />
              <DButton
                class="btn-primary ai-search-answer__follow-up-submit"
                @disabled={{or
                  this.startingConversation
                  (and (not this.followUpValue) (not this.suggestedFollowUp))
                }}
                @icon="paper-plane"
                @label="discourse_ai.ai_search.ask"
                @type="submit"
              />
            </form>
          {{/if}}
        </div>
      {{/if}}

      {{! over the foot of the answer until it is opened, so offering them
          moves nothing }}
      {{#if this.showActions}}
        <div class="ai-search-answer__actions">
          {{#if this.discoveries.loadingDiscoveries}}
            {{! holds the button's place while the answer loads }}
            <DSkeleton
              class="ai-search-answer__expand-skeleton"
              @variant="rect"
            />
          {{else if this.hasMore}}
            <DButton
              class="btn-default btn-small ai-search-answer__expand"
              @action={{this.session.toggleExpanded}}
              @label={{if
                this.expanded
                "discourse_ai.ai_search.show_less"
                "discourse_ai.ai_search.show_more"
              }}
            />
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
