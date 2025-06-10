import { eq } from "truth-helpers";

const TranslationPlaceholder = <template>
  {{#if (eq @placeholder @name)}}
    {{yield}}
  {{/if}}
</template>;

export default TranslationPlaceholder;
