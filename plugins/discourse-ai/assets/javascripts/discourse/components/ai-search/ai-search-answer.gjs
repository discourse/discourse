import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

/**
 * The answer, its related topics and the follow-up field for the current
 * combined search. Asking a follow-up opens the conversation on the full page.
 */
export default class AiSearchAnswer extends Component {
  @service aiSearchSession;
  @service router;
  @service siteSettings;

  @tracked followUpValue = "";
  @tracked startingConversation = false;
  @tracked overflowing = false;
  @tracked expandedFor = null;

  // The box keeps its height while the answer streams, so a long answer is cut
  // off with a way to open it rather than growing and pushing what is below.
  watchOverflow = modifier((body) => {
    const content = body.querySelector(".ai-search-answer__content");
    const observer = new ResizeObserver(() => {
      if (!this.expanded) {
        this.overflowing = content.scrollHeight > body.clientHeight + 1;
      }
    });
    observer.observe(content);
    return () => observer.disconnect();
  });

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

  get expanded() {
    return this.expandedFor === this.session.query;
  }

  get relatedSkeletons() {
    return Array.from({
      length: this.siteSettings.ai_ask_ai_related_count || 2,
    });
  }

  get showRelatedSkeletons() {
    return (
      !this.session.answerSettled && this.session.relatedTopics.length === 0
    );
  }

  get suggestedFollowUp() {
    return this.discoveries.suggestedFollowUp || "";
  }

  @action
  toggleExpanded() {
    this.expandedFor = this.expanded ? null : this.session.query;
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
      }}
      {{on "click" this.followLink}}
    >
      <div
        class={{dConcatClass
          "ai-search-answer__body"
          (if this.overflowing "--overflowing")
          (if this.expanded "--expanded")
        }}
        {{this.watchOverflow}}
      >
        <div class="ai-search-answer__content">
          {{#if
            (and
              this.session.scopeFallback
              this.session.scope
              (not this.session.answerFailed)
            )
          }}
            <p class="ai-search-answer__scope-note">
              {{i18n
                "discourse_ai.ai_search.scope.fallback"
                name=this.session.scope.label
              }}
            </p>
          {{/if}}
          {{#if this.discoveries.loadingDiscoveries}}
            <DSkeleton class="ai-search-answer__title-skeleton" @width="60%" />
            <DSkeleton @count={{3}} @lastLineWidth="45%" />
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
        {{#if this.overflowing}}
          <DButton
            class="btn-default btn-small ai-search-answer__expand"
            @action={{this.toggleExpanded}}
            @label={{if
              this.expanded
              "discourse_ai.ai_search.show_less"
              "discourse_ai.ai_search.show_more"
            }}
          />
        {{/if}}
      </div>

      <ul class="ai-search-answer__related">
        {{#if this.showRelatedSkeletons}}
          {{#each this.relatedSkeletons}}
            <li class="ai-search-answer__related-item --skeleton">
              <DSkeleton @width="80%" />
              <DSkeleton @count={{2}} @lastLineWidth="60%" />
            </li>
          {{/each}}
        {{else}}
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
        {{/if}}
      </ul>
    </section>

    <form
      class={{dConcatClass
        "ai-search-answer__follow-up"
        (unless this.session.canFollowUp "--disabled")
      }}
      {{on "submit" this.startConversation}}
    >
      <input
        aria-label={{i18n "discourse_ai.ai_search.follow_up_label"}}
        class="ai-search-answer__follow-up-input"
        disabled={{not this.session.canFollowUp}}
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
          (not this.session.canFollowUp)
          this.startingConversation
          (and (not this.followUpValue) (not this.suggestedFollowUp))
        }}
        @icon="paper-plane"
        @label="discourse_ai.ai_search.ask"
        @type="submit"
      />
    </form>

    <p class="ai-search-answer__rewrites">
      {{#if this.session.rewriteResolved}}
        <span class="ai-search-answer__rewrite">
          {{i18n "discourse_ai.ai_search.keywords_label"}}
          <strong>{{this.session.keywordQuery}}</strong>
        </span>
      {{else}}
        <DSkeleton @width="50%" />
      {{/if}}
      {{#if this.session.dismissedScope}}
        <DButton
          class="btn-link ai-search-answer__restore-scope"
          @action={{this.session.restoreScope}}
          @translatedLabel={{i18n
            "discourse_ai.ai_search.scope.restore"
            name=this.session.dismissedScope.label
          }}
        />
      {{/if}}
    </p>
  </template>
}
