import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";

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

  @action
  copy() {
    clipboardCopy(this.args.payload || "");
    this.args.onCopy?.();
  }

  <template>
    <div class="ai-payload-viewer" ...attributes>
      {{#if @payload}}
        {{#if @truncated}}
          <p class="ai-payload-viewer__notice">
            {{@truncatedMessage}}
          </p>
        {{/if}}
        <pre class="ai-payload-viewer__content" tabindex="0"><code
          >{{this.content}}</code></pre>
        <DButton
          class="btn-default ai-payload-viewer__copy"
          @icon="copy"
          @action={{this.copy}}
          @translatedLabel={{@copyLabel}}
        />
      {{else}}
        <p class="ai-payload-viewer__empty">{{@emptyMessage}}</p>
      {{/if}}
    </div>
  </template>
}
