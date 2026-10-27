import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const DConditionalLoadingSection = <template>
  <div
    class={{dConcatClass
      "conditional-loading-section"
      (if @isLoading "is-loading")
    }}
    ...attributes
  >
    {{#if @isLoading}}
      <span class="title">{{or
          @title
          (i18n "conditional_loading_section.loading")
        }}</span>
      <div class="spinner {{@size}}"></div>
    {{else}}
      {{yield}}
    {{/if}}
  </div>
</template>;

export default DConditionalLoadingSection;
