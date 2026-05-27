import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import { i18n } from "discourse-i18n";

export default class ReviewableAiToolAction extends Component {
  get toolParameters() {
    const params = this.args.reviewable.tool_parameters;
    if (!params || typeof params !== "object") {
      return [];
    }
    return Object.entries(params).map(([key, value]) => ({
      key,
      value: typeof value === "object" ? JSON.stringify(value) : String(value),
    }));
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n
          "discourse_ai.reviewables.ai_tool_action.agent"
        }}</div>
      <div
        class="review-item__meta-value"
      >{{@reviewable.payload.agent_name}}</div>

      <div class="review-item__meta-label">{{i18n
          "discourse_ai.reviewables.ai_tool_action.tool"
        }}</div>
      <div class="review-item__meta-value">{{@reviewable.tool_name}}</div>

      {{#if this.toolParameters.length}}
        <div class="review-item__meta-label">{{i18n
            "discourse_ai.reviewables.ai_tool_action.parameters"
          }}</div>
        <div class="review-item__meta-value">
          <ul>
            {{#each this.toolParameters as |param|}}
              <li><strong>{{param.key}}</strong>: {{param.value}}</li>
            {{/each}}
          </ul>
        </div>
      {{/if}}
    </div>

    {{#if @reviewable.cooked}}
      <div class="review-item__post">
        <div class="review-item__post-content-wrapper">
          <DDecoratedHtml
            @className="review-item__post-content"
            @html={{trustHTML @reviewable.cooked}}
            @model={{@reviewable}}
          />
        </div>
      </div>
    {{/if}}

    {{yield}}
  </template>
}
