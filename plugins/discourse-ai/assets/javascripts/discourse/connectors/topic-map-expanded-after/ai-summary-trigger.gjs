import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import EmbedMode from "discourse/lib/embed-mode";
import DButton from "discourse/ui-kit/d-button";
import AiSummaryModal from "../../components/modal/ai-summary-modal.gjs";

export default class AiSummaryTrigger extends Component {
  @service aiCredits;
  @service currentUser;
  @service modal;
  @service tooltip;

  @tracked creditStatus = null;
  @tracked creditCheckComplete = false;
  @tracked showInlineSummary = false;

  creditLimitTooltipModifier = modifier((element) => {
    if (!this.isDisabled) {
      return;
    }

    const instance = this.tooltip.register(element, {
      identifier: "ai-credit-limit-tooltip",
      content: trustHTML(
        this.aiCredits.getCreditLimitMessage(this.creditStatus)
      ),
      placement: "top",
      triggers: "hover",
      interactive: true,
    });

    return () => instance.destroy();
  });

  get isAiConversation() {
    return this.args.outletArgs.topic.is_bot_pm;
  }

  get hasCachedSummary() {
    return this.args.outletArgs.topic.has_cached_summary;
  }

  get isDisabled() {
    if (this.hasCachedSummary) {
      return false;
    }
    if (!this.creditCheckComplete) {
      return false;
    }
    return this.creditStatus?.hard_limit_reached === true;
  }

  @action
  async checkCredits() {
    this.creditStatus = null;
    this.creditCheckComplete = false;

    if (!this.currentUser || EmbedMode.enabled) {
      this.creditCheckComplete = true;
      return;
    }

    try {
      this.creditStatus =
        await this.aiCredits.getFeatureCreditStatus("topic_summaries");
    } catch {
      this.creditStatus = null;
    } finally {
      this.creditCheckComplete = true;
    }
  }

  @action
  openAiSummary() {
    if (this.isDisabled) {
      return;
    }
    if (this.args.inline) {
      this.showInlineSummary = true;
      return;
    }

    this.modal.show(AiSummaryModal, {
      model: {
        topic: this.args.outletArgs.topic,
        postStream: this.args.outletArgs.postStream,
      },
    });
  }

  <template>
    {{#unless this.isAiConversation}}
      {{#if @outletArgs.topic.summarizable}}
        <section
          class="topic-map__additional-contents toggle-summary"
          {{didInsert this.checkCredits}}
          {{didUpdate this.checkCredits @outletArgs.topic.id}}
          {{this.creditLimitTooltipModifier}}
        >
          {{#if this.showInlineSummary}}
            <AiSummaryModal
              @inline={{true}}
              @model={{hash
                topic=@outletArgs.topic
                postStream=@outletArgs.postStream
              }}
            />
          {{else}}
            <DButton
              class="btn-default ai-summarization-button"
              @action={{this.openAiSummary}}
              @disabled={{this.isDisabled}}
              @icon="discourse-sparkles"
              @label="summary.buttons.generate"
            />
          {{/if}}
        </section>
      {{/if}}
    {{/unless}}
  </template>
}
