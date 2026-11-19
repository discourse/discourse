import { on } from "@ember/modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// The shell every row shares: a header that toggles, and a body that exists
// only while the row is open.
export default <template>
  <div
    class={{dConcatClass "ba-row" (if @expanded "open") (if @loaded "loaded")}}
  >
    <button
      aria-expanded={{if @expanded "true" "false"}}
      class="ba-head"
      type="button"
      {{on "click" @toggle}}
    >
      <span class="ba-name">
        {{dIcon "caret-right" class="ba-tw"}}
        {{#if @loaded}}
          <span
            class="ba-loaded-dot"
            title="Loaded in this browser session"
          >●</span>
        {{/if}}
        {{yield to="name"}}
      </span>
      {{yield to="numbers"}}
    </button>
    {{#if @expanded}}
      <div class="ba-body">{{yield to="body"}}</div>
    {{/if}}
  </div>
</template>
