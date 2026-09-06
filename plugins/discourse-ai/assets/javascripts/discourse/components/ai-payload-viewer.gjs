import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import DCopyButton from "discourse/ui-kit/d-copy-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const JSON_FORMAT_LIMIT = 200_000;

export default class AiPayloadViewer extends Component {
  @cached
  get content() {
    const payload = this.args.payload;
    if (!payload) {
      return "";
    }

    if (payload.length > JSON_FORMAT_LIMIT) {
      return payload;
    }

    try {
      return JSON.stringify(JSON.parse(payload), null, 2);
    } catch {
      return payload;
    }
  }

  <template>
    <div
      class={{dConcatClass "ai-payload-viewer" (if @unbounded "--unbounded")}}
      ...attributes
    >
      {{#if @payload}}
        {{#if @truncated}}
          <p class="ai-payload-viewer__notice">
            {{@truncatedMessage}}
          </p>
        {{/if}}
        <pre
          class="ai-payload-viewer__content"
          tabindex={{if @unbounded undefined "0"}}
        ><code>{{this.content}}</code></pre>
        {{#if @copyLabel}}
          <DCopyButton
            @value={{@payload}}
            @copyClass="btn-default ai-payload-viewer__copy"
            @translatedLabel={{@copyLabel}}
            @translatedLabelAfterCopy={{i18n "discourse_ai.copied"}}
            @copied={{@onCopy}}
          />
        {{/if}}
      {{else}}
        <p class="ai-payload-viewer__empty">{{@emptyMessage}}</p>
      {{/if}}
    </div>
  </template>
}
