import type { TOC } from "@ember/component/template-only";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

interface DConditionalLoadingSectionSignature {
  Args: {
    /** Whether the content is still loading. While it is, a title and a spinner replace it. */
    isLoading?: boolean;

    /** The title shown while loading. When omitted, a generic "Loading" title is shown. */
    title?: string;

    /** The spinner size, such as `small`. */
    size?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** The content to reveal once loading has finished. */
    default: [];
  };
}

const DConditionalLoadingSection: TOC<DConditionalLoadingSectionSignature> =
  <template>
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
