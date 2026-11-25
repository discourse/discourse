import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import htmlClass from "discourse/helpers/html-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { smartShortDate } from "discourse/lib/formatter";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSummarySkeleton from "../../components/ai-summary-skeleton.gjs";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "../../lib/ai-errors.js";
import SmoothStreamer from "../../lib/smooth-streamer.gjs";

const AiSummaryBody = <template>
  <div class="ai-summary-container" {{didInsert @summary.generateSummary}}>
    <article
      class={{dConcatClass
        "ai-summary-box"
        "streamable-content"
        (if @summary.smoothStreamer.isStreaming "streaming")
      }}
    >
      {{#if @summary.loading}}
        <AiSummarySkeleton />
      {{else}}
        <div class="generated-summary cooked">
          <DCookText @rawText={{@summary.smoothStreamer.renderedText}} />
        </div>
      {{/if}}
    </article>
  </div>
</template>;

const AiSummaryFooter = <template>
  <p class="summarized-on">
    {{i18n "summary.summarized_on" date=@summary.summarizedOn}}
    <DTooltip @placements={{array "top-end"}}>
      <:trigger>
        {{dIcon "circle-info"}}
      </:trigger>
      <:content>
        {{i18n "summary.model_used" model=@summary.summarizedBy}}
      </:content>
    </DTooltip>
  </p>
  {{#if @summary.outdated}}
    <p class="summary-outdated">{{@summary.outdatedSummaryWarningText}}</p>
  {{/if}}
  {{#if @summary.canRegenerate}}
    <DButton
      @action={{@summary.regenerateSummary}}
      @icon="arrows-rotate"
      @label="summary.buttons.regenerate"
      @title="summary.buttons.regenerate"
    />
  {{/if}}
</template>;

export default class AiSummaryModal extends Component {
  @service messageBus;
  @service currentUser;
  @service modal;

  @tracked text = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;
  @tracked loading = false;
  @tracked currentIndex = 0;
  smoothStreamer = new SmoothStreamer(
    () => this.text,
    (newValue) => (this.text = newValue)
  );

  #channel;

  get outdatedSummaryWarningText() {
    let outdatedText = i18n("summary.outdated");

    if (!this.topRepliesSummaryEnabled && this.newPostsSinceSummary > 0) {
      outdatedText += " ";
      outdatedText += i18n("summary.outdated_posts", {
        count: this.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  get topRepliesSummaryEnabled() {
    return this.args.model.postStream.summary;
  }

  get topicId() {
    return this.args.model.topic.id;
  }

  get baseSummarizationURL() {
    return `/discourse-ai/summarization/t/${this.topicId}`;
  }

  resetSummary() {
    this.smoothStreamer.resetStreaming();
    this.currentIndex = 0;
    this.text = "";
    this.summarizedOn = null;
    this.summarizedBy = null;
    this.newPostsSinceSummary = null;
    this.outdated = false;
    this.canRegenerate = false;
    this.loading = false;
  }

  @bind
  subscribe() {
    const channel = `/discourse-ai/summaries/topic/${this.topicId}`;
    if (this.#channel === channel) {
      return;
    }

    this.unsubscribe();
    this.#channel = channel;
    this.messageBus.subscribe(channel, this._updateSummary);
  }

  @bind
  unsubscribe() {
    if (this.#channel) {
      this.messageBus.unsubscribe(this.#channel, this._updateSummary);
      this.#channel = null;
      this.resetSummary();
    }
  }

  @action
  generateSummary() {
    let ajaxOpts = {};

    if (this.currentUser && !this.args.model.topic.has_cached_summary) {
      ajaxOpts.type = "POST";
      ajaxOpts.data = { stream: true };
    }

    return this._requestSummary(this.baseSummarizationURL, ajaxOpts);
  }

  @action
  regenerateSummary() {
    let ajaxOpts = {};

    if (this.currentUser) {
      ajaxOpts.type = "POST";
      ajaxOpts.data = { stream: true };

      if (this.canRegenerate) {
        ajaxOpts.data.skip_age_check = true;
      }
    }

    // ensure summary is reset before requesting a new one:
    this.resetSummary();
    return this._requestSummary(this.baseSummarizationURL, ajaxOpts);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  handleClose() {
    this.modal.triggerElement = null; // prevent refocus of trigger, which changes scroll position
    this.args.closeModal();
  }

  @action
  _requestSummary(url, ajaxOpts = {}) {
    if (this.loading || (this.text && !this.canRegenerate)) {
      return;
    }

    this.loading = true;
    this.summarizedOn = null;

    const topicId = this.topicId;
    return ajax(url, ajaxOpts)
      .then((data) => {
        if (
          !this.isDestroying &&
          topicId === this.topicId &&
          data?.ai_topic_summary?.summarized_text
        ) {
          data.done = true;
          this._updateSummary(data);
        }
      })
      .catch((error) => {
        if (this.isDestroying || topicId !== this.topicId) {
          return;
        }

        this.loading = false;
        if (isAiCreditLimitError(error)) {
          popupAiCreditLimitError(error);
        } else {
          throw error;
        }
      });
  }

  @bind
  async _updateSummary(update) {
    if (isAiCreditLimitError(update)) {
      this.loading = false;
      popupAiCreditLimitError(update);
      this.unsubscribe();
      return;
    }

    const topicSummary = {
      done: update.done,
      raw: update.ai_topic_summary?.summarized_text,
      ...update.ai_topic_summary,
    };

    this.loading = false;
    this.smoothStreamer.updateResult(topicSummary, "raw");

    if (update.done) {
      this.summarizedOn = smartShortDate(
        moment(topicSummary.updated_at, "YYYY-MM-DD HH:mm:ss Z").toDate()
      );
      this.summarizedBy = topicSummary.algorithm;
      this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
      this.outdated = topicSummary.outdated;
      this.canRegenerate = topicSummary.outdated && topicSummary.can_regenerate;
    }
  }

  <template>
    {{#if @inline}}
      <div
        class="ai-summary-inline"
        {{didInsert this.subscribe}}
        {{willDestroy this.unsubscribe}}
      >
        <AiSummaryBody @summary={{this}} />
        {{#if this.summarizedOn}}
          <AiSummaryFooter @summary={{this}} />
        {{/if}}
      </div>
    {{else}}
      <DModal
        class="ai-summary-modal"
        @bodyClass="ai-summary-modal__body"
        @closeModal={{this.handleClose}}
        @hideFooter={{not this.summarizedOn}}
        @title={{i18n "discourse_ai.summarization.topic.title"}}
        {{didInsert this.subscribe}}
        {{didUpdate this.subscribe @model.topic.id}}
        {{willDestroy this.unsubscribe}}
      >
        <:body>
          {{htmlClass "scrollable-modal"}}
          <AiSummaryBody @summary={{this}} />
        </:body>
        <:footer>
          <AiSummaryFooter @summary={{this}} />
        </:footer>
      </DModal>
    {{/if}}
  </template>
}
