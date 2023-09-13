import concatClass from "discourse/helpers/concat-class";
import eq from "truth-helpers/helpers/eq";

const ConditionalLoadingSpinner = <template>
  <div
    class={{concatClass
      "loading-container"
      (if @condition "visible")
      (if (eq @size "small") "inline-spinner")
    }}
  >
    {{#if @condition}}
      <div class="spinner {{@size}}"></div>
    {{else}}
      {{yield}}
    {{/if}}
  </div>
</template>;

export default ConditionalLoadingSpinner;
