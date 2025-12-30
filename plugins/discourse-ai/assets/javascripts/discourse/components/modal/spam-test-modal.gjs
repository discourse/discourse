import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AiIndicatorWave from "../ai-indicator-wave";

export default class SpamTestModal extends Component {
  @tracked testResult;
  @tracked isLoading = false;
  @tracked postUrl = "";
  @tracked isSpam;
  @tracked reason;
  @tracked llmName;
  @tracked systemPrompt;
  @tracked sentMessage;
  @tracked scanHistory;

  @action
  async runTest() {
    this.isLoading = true;
    try {
      const response = await ajax(
        `/admin/plugins/discourse-ai/ai-spam/test.json`,
        {
          type: "POST",
          data: {
            post_url: this.postUrl,
            custom_instructions: this.args.model.customInstructions,
            llm_id: this.args.model.llmId,
          },
        }
      );

      this.isSpam = response.is_spam;
      this.testResult = response.is_spam
        ? i18n("discourse_ai.spam.test_modal.spam")
        : i18n("discourse_ai.spam.test_modal.not_spam");
      this.reason = response.reason;
      this.llmName = response.llm_name;
      this.systemPrompt = response.system_prompt;
      this.sentMessage = response.sent_message;
      this.scanHistory = response.scan_history;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.spam.test_modal.title"}}
      @closeModal={{@closeModal}}
      @bodyClass="spam-test-modal__body"
      class="spam-test-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "discourse_ai.spam.test_modal.post_url_label"}}</label>
          <input
            {{on "input" (withEventValue (fn (mut this.postUrl)))}}
            type="text"
            placeholder={{i18n
              "discourse_ai.spam.test_modal.post_url_placeholder"
            }}
          />
        </div>

        {{#if this.testResult}}
          <div class="spam-test-modal__results">
            <div
              class="spam-test-modal__verdict
                {{if this.isSpam 'is-spam' 'not-spam'}}"
            >
              {{this.testResult}}
            </div>

            {{#if this.reason}}
              <div
                class="spam-test-modal__info-box spam-test-modal__info-box--reason"
              >
                <h4 class="spam-test-modal__info-box-title">{{i18n
                    "discourse_ai.spam.test_modal.reason"
                  }}</h4>
                <div class="spam-test-modal__info-box-content">
                  <p>{{this.reason}}</p>
                </div>
              </div>
            {{/if}}

            <div class="spam-test-modal__info-grid">
              {{#if this.llmName}}
                <div
                  class="spam-test-modal__info-box spam-test-modal__info-box--llm"
                >
                  <h4 class="spam-test-modal__info-box-title">{{i18n
                      "discourse_ai.spam.test_modal.llm"
                    }}</h4>
                  <div class="spam-test-modal__info-box-content">
                    {{this.llmName}}
                  </div>
                </div>
              {{/if}}

              {{#if this.scanHistory}}
                <div
                  class="spam-test-modal__info-box spam-test-modal__info-box--history"
                >
                  <h4 class="spam-test-modal__info-box-title">{{i18n
                      "discourse_ai.spam.test_modal.scan_history"
                    }}</h4>
                  <div class="spam-test-modal__info-box-content">
                    <pre>{{this.scanHistory}}</pre>
                  </div>
                </div>
              {{/if}}
            </div>

            {{#if this.sentMessage}}
              <div
                class="spam-test-modal__info-box spam-test-modal__info-box--message"
              >
                <h4 class="spam-test-modal__info-box-title">{{i18n
                    "discourse_ai.spam.test_modal.sent_message"
                  }}</h4>
                <div class="spam-test-modal__info-box-content">
                  <pre>{{this.sentMessage}}</pre>
                </div>
              </div>
            {{/if}}

            {{#if this.systemPrompt}}
              <div
                class="spam-test-modal__info-box spam-test-modal__info-box--prompt"
              >
                <h4 class="spam-test-modal__info-box-title">{{i18n
                    "discourse_ai.spam.test_modal.system_prompt"
                  }}</h4>
                <div class="spam-test-modal__info-box-content">
                  <pre>{{this.systemPrompt}}</pre>
                </div>
              </div>
            {{/if}}
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          @action={{this.runTest}}
          @label="discourse_ai.spam.test_modal.run"
          @disabled={{this.isLoading}}
          class="btn-primary spam-test-modal__run-button"
        >
          <AiIndicatorWave @loading={{this.isLoading}} />
        </DButton>
      </:footer>
    </DModal>
  </template>
}
