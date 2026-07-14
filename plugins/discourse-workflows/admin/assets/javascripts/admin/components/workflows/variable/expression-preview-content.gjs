import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

const VALID_STATES = new Set([
  "valid",
  "invalid",
  "undefined",
  "warning",
  "pending",
  "empty",
]);

const I18N_PREFIX = "discourse_workflows.expression_preview";

export default class ExpressionPreviewContent extends Component {
  get displaySegments() {
    const segments = this.args.data?.segments;
    if (!segments?.length) {
      return [];
    }

    return segments.map((seg) => {
      if (seg.kind === "plaintext") {
        return { className: "expression-preview__plaintext", text: seg.text };
      }

      const state = VALID_STATES.has(seg.state) ? seg.state : "pending";
      if (state === "valid" && seg.text.length > 0) {
        return {
          className: `expression-preview__resolved --${state}`,
          text: seg.text,
        };
      }

      const labelState = state === "valid" ? "empty" : state;
      return {
        className: `expression-preview__resolved --${labelState} --label`,
        text: i18n(`${I18N_PREFIX}.${labelState}`),
      };
    });
  }

  <template>
    <div class="expression-preview">
      <span class="expression-preview__label">
        {{i18n "discourse_workflows.expression_preview.result"}}
      </span>
      <span class="expression-preview__result">
        {{~#each this.displaySegments as |seg|~}}
          <span class={{seg.className}}>{{seg.text}}</span>
        {{~/each~}}
      </span>
    </div>
  </template>
}
