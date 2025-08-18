import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DiffStreamer from "../../lib/diff-streamer";
import SmoothStreamer from "../../lib/smooth-streamer";
import AiIndicatorWave from "../ai-indicator-wave";

export default class ModalDiffModal extends Component {
  @service messageBus;

  @tracked loading = false;
  @tracked finalResult = "";
  @tracked escapedSelectedText = escapeExpression(this.args.model.selectedText);
  @tracked diffStreamer = new DiffStreamer(this.args.model.selectedText);
  @tracked suggestion = "";
  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.suggestion,
    (newValue) => (this.suggestion = newValue)
  );

  constructor() {
    super(...arguments);
    this.suggestChanges();
  }

  get diffResult() {
    if (this.loading) {
      return this.escapedSelectedText;
    }

    if (this.diffStreamer.diff?.length > 0) {
      return this.diffStreamer.diff;
    }

    // Prevents flash by showing the
    // original text when the diff is empty
    return this.escapedSelectedText;
  }

  get smoothStreamerResult() {
    if (this.loading) {
      return this.escapedSelectedText;
    }

    return this.smoothStreamer.renderedText;
  }

  get isStreaming() {
    // diffStreamer stops Streaming when it is finished with a chunk, looking at isDone is safe
    // it starts off not done
    if (this.args.model.showResultAsDiff) {
      return !this.diffStreamer.isDone;
    }

    return this.smoothStreamer.isStreaming;
  }

  get primaryBtnLabel() {
    return this.loading
      ? i18n("discourse_ai.ai_helper.context_menu.loading")
      : i18n("discourse_ai.ai_helper.context_menu.confirm");
  }

  get primaryBtnDisabled() {
    return this.loading || this.isStreaming;
  }

  set progressChannel(value) {
    if (this._progressChannel) {
      this.messageBus.unsubscribe(this._progressChannel, this.updateResult);
    }
    this._progressChannel = value;
    this.subscribe();
  }

  subscribe() {
    // we have 1 channel per operation so we can safely subscribe at head
    this.messageBus.subscribe(this._progressChannel, this.updateResult, 0);
  }

  @bind
  cleanup() {
    // stop all callbacks so it does not end up streaming pointlessly
    this.#resetState();
    if (this._progressChannel) {
      this.messageBus.unsubscribe(this._progressChannel, this.updateResult);
    }
  }

  @action
  updateResult(result) {
    this.loading = false;

    if (result.done) {
      this.finalResult = result.result;
      this.loading = false;
    }

    if (this.args.model.showResultAsDiff) {
      this.diffStreamer.updateResult(result, "result");
    } else {
      this.smoothStreamer.updateResult(result, "result");
    }
  }

  @action
  async suggestChanges() {
    this.#resetState();

    try {
      this.loading = true;
      const result = await ajax("/discourse-ai/ai-helper/stream_suggestion", {
        method: "POST",
        data: {
          location: "composer",
          mode: this.args.model.mode,
          text: this.args.model.selectedText,
          custom_prompt: this.args.model.customPromptValue,
          force_default_locale: true,
          client_id: this.messageBus.clientId,
        },
      });

      this.progressChannel = result.progress_channel;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  triggerConfirmChanges() {
    this.args.closeModal();

    if (this.suggestion) {
      this.args.model.toolbarEvent.replaceText(
        this.args.model.selectedText,
        this.suggestion
      );
    }

    const finalResult =
      this.finalResult?.length > 0
        ? this.finalResult
        : this.diffStreamer.suggestion;

    if (this.args.model.showResultAsDiff && finalResult) {
      this.args.model.toolbarEvent.replaceText(
        this.args.model.selectedText,
        finalResult
      );
    }
  }

  @action
  cleanupAndClose() {
    this.#resetState();
    this.loading = false;
    this.args.closeModal();
  }

  #resetState() {
    this.suggestion = "";
    this.finalResult = "";
    this.smoothStreamer.resetStreaming();
    this.diffStreamer.reset();
  }

  <template>
    <DModal
      class="composer-ai-helper-modal"
      @title={{i18n "discourse_ai.ai_helper.context_menu.changes"}}
      @closeModal={{this.cleanupAndClose}}
    >
      <:body>
        <div {{willDestroy this.cleanup}} class="text-preview">
          <div
            class={{concatClass
              "composer-ai-helper-modal__suggestion"
              "streamable-content"
              (if this.isStreaming "streaming")
              (if @model.showResultAsDiff "inline-diff")
              (if this.diffStreamer.isThinking "thinking")
              (if this.loading "composer-ai-helper-modal__loading")
            }}
          >
            {{~#if @model.showResultAsDiff~}}
              <span class="diff-inner">{{htmlSafe this.diffResult}}</span>
            {{else}}
              {{#if (or this.loading this.smoothStreamer.isStreaming)}}
                <CookText
                  @rawText={{this.smoothStreamerResult}}
                  class="cooked"
                />
              {{else}}
                <div class="composer-ai-helper-modal__old-value">
                  {{~this.escapedSelectedText~}}
                </div>
                <div class="composer-ai-helper-modal__new-value">
                  <CookText
                    @rawText={{this.smoothStreamerResult}}
                    class="cooked"
                  />
                </div>
              {{/if}}
            {{/if}}
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary confirm"
          @disabled={{this.primaryBtnDisabled}}
          @action={{this.triggerConfirmChanges}}
          @translatedLabel={{this.primaryBtnLabel}}
        >
          {{#if this.loading}}
            <AiIndicatorWave @loading={{this.loading}} />
          {{/if}}
        </DButton>
        <DButton
          class="btn-flat discard"
          @action={{this.cleanupAndClose}}
          @label="discourse_ai.ai_helper.context_menu.discard"
        />
        <DButton
          class="regenerate"
          @icon="arrows-rotate"
          @action={{this.suggestChanges}}
          @label="discourse_ai.ai_helper.context_menu.regen"
        />
      </:footer>
    </DModal>
  </template>
}
