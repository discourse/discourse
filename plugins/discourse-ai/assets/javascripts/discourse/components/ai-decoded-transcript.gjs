import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  isDecodedResponse,
  isValidDecodedToolCall,
  isValidDecodedToolResult,
} from "discourse/plugins/discourse-ai/discourse/lib/decoded-response";

export default class AiDecodedTranscript extends Component {
  @cached
  get transcript() {
    const response = this.args.response;
    if (!isDecodedResponse(response)) {
      return null;
    }

    const transcript = {
      thinking: this.#format(response.thinking),
      toolCalls: this.#toolCalls(response.tool_calls),
      toolResults: this.#toolResults(response.tool_results),
      response: this.#format(response.response),
    };

    return transcript.thinking ||
      transcript.response ||
      transcript.toolCalls.length ||
      transcript.toolResults.length
      ? transcript
      : null;
  }

  #toolCalls(toolCalls) {
    if (!Array.isArray(toolCalls)) {
      return [];
    }

    return toolCalls.filter(isValidDecodedToolCall).map((call) => {
      return {
        name:
          this.#format(call.name) ||
          i18n("discourse_ai.ai_decoded_transcript.tool"),
        id: this.#format(call.id),
        arguments: this.#format(call.arguments),
      };
    });
  }

  #toolResults(toolResults) {
    if (!Array.isArray(toolResults)) {
      return [];
    }

    return toolResults.filter(isValidDecodedToolResult).map((result) => {
      return {
        callId: this.#format(result.call_id),
        type: this.#format(result.type),
        content: this.#format(result.result),
        isError: result.is_error === true,
      };
    });
  }

  #format(value) {
    if (value === undefined || value === null) {
      return "";
    }

    if (typeof value === "string") {
      return value;
    }

    return JSON.stringify(value, null, 2);
  }

  <template>
    {{#if this.transcript}}
      <div class="ai-decoded-transcript" ...attributes>
        {{#if this.transcript.thinking}}
          <details class="ai-decoded-transcript__thinking" open>
            <summary class="ai-decoded-transcript__summary">
              {{i18n "discourse_ai.ai_decoded_transcript.thinking"}}
            </summary>
            <div
              class="ai-decoded-transcript__text"
            >{{this.transcript.thinking}}</div>
          </details>
        {{/if}}

        {{#if this.transcript.toolCalls.length}}
          <section class="ai-decoded-transcript__section --tool-calls">
            <h2 class="ai-decoded-transcript__heading">
              {{i18n "discourse_ai.ai_decoded_transcript.tool_calls"}}
            </h2>
            <ol class="ai-decoded-transcript__list" role="list">
              {{#each this.transcript.toolCalls as |toolCall|}}
                <li class="ai-decoded-transcript__item">
                  <h3 class="ai-decoded-transcript__item-heading">
                    {{toolCall.name}}
                  </h3>
                  {{#if toolCall.id}}
                    <dl class="ai-decoded-transcript__metadata">
                      <dt>{{i18n
                          "discourse_ai.ai_decoded_transcript.call_id"
                        }}</dt>
                      <dd>{{toolCall.id}}</dd>
                    </dl>
                  {{/if}}
                  <h4 class="ai-decoded-transcript__label">
                    {{i18n "discourse_ai.ai_decoded_transcript.arguments"}}
                  </h4>
                  <pre
                    class="ai-decoded-transcript__code"
                    dir="ltr"
                  >{{toolCall.arguments}}</pre>
                </li>
              {{/each}}
            </ol>
          </section>
        {{/if}}

        {{#if this.transcript.toolResults.length}}
          <section class="ai-decoded-transcript__section --tool-results">
            <h2 class="ai-decoded-transcript__heading">
              {{i18n "discourse_ai.ai_decoded_transcript.tool_results"}}
            </h2>
            <ol class="ai-decoded-transcript__list" role="list">
              {{#each this.transcript.toolResults as |toolResult|}}
                <li
                  class={{dConcatClass
                    "ai-decoded-transcript__item"
                    (if toolResult.isError "--error")
                  }}
                >
                  <h3 class="ai-decoded-transcript__item-heading">
                    {{i18n "discourse_ai.ai_decoded_transcript.tool_result"}}
                    {{#if toolResult.isError}}
                      <span class="ai-decoded-transcript__error">
                        {{i18n "discourse_ai.ai_decoded_transcript.error"}}
                      </span>
                    {{/if}}
                  </h3>
                  {{#if toolResult.callId}}
                    <dl class="ai-decoded-transcript__metadata">
                      <dt>{{i18n
                          "discourse_ai.ai_decoded_transcript.call_id"
                        }}</dt>
                      <dd>{{toolResult.callId}}</dd>
                    </dl>
                  {{/if}}
                  {{#if toolResult.type}}
                    <dl class="ai-decoded-transcript__metadata">
                      <dt>{{i18n
                          "discourse_ai.ai_decoded_transcript.type"
                        }}</dt>
                      <dd>{{toolResult.type}}</dd>
                    </dl>
                  {{/if}}
                  <pre
                    class="ai-decoded-transcript__code"
                    dir="ltr"
                  >{{toolResult.content}}</pre>
                </li>
              {{/each}}
            </ol>
          </section>
        {{/if}}

        {{#if this.transcript.response}}
          <section class="ai-decoded-transcript__section --response">
            <h2 class="ai-decoded-transcript__heading">
              {{i18n "discourse_ai.ai_decoded_transcript.response"}}
            </h2>
            <div
              class="ai-decoded-transcript__text"
            >{{this.transcript.response}}</div>
          </section>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
