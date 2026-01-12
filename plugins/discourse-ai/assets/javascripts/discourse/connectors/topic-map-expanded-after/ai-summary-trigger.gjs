import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import AiSummaryModal from "../../components/modal/ai-summary-modal";

export default class AiSummaryTrigger extends Component {
  @service aiCredits;
  @service currentUser;
  @service modal;
  @service tooltip;

  @tracked creditStatus = null;
  @tracked creditCheckComplete = false;

  creditLimitTooltipModifier = modifier((element) => {
    if (!this.isDisabled) {
      return;
    }

    const instance = this.tooltip.register(element, {
      identifier: "ai-credit-limit-tooltip",
      content: htmlSafe(
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

    if (!this.currentUser) {
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
  openAiSummaryModal() {
    if (this.isDisabled) {
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
          <DButton
            @label="summary.buttons.generate"
            @icon="discourse-sparkles"
            @action={{this.openAiSummaryModal}}
            @disabled={{this.isDisabled}}
            class="btn-default ai-summarization-button"
          />
        </section>
      {{/if}}
    {{/unless}}
  </template>
}
