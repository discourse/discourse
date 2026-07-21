import type { TemplateOnlyComponent } from "@ember/component/template-only";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface DConditionalLoadingSpinnerSignature {
  Args: {
    /** Whether the content is still loading. */
    condition?: boolean;

    /** The spinner size. */
    size?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** The content to reveal once loading has finished. */
    default: [];
  };
}

const DConditionalLoadingSpinner: TemplateOnlyComponent<DConditionalLoadingSpinnerSignature> =
  <template>
    <PluginOutlet
      @name="conditional-loading-spinner"
      @defaultGlimmer={{true}}
      @outletArgs={{lazyHash condition=@condition size=@size}}
    >
      <div
        class={{dConcatClass
          "loading-container"
          (if @condition "visible")
          (if (eq @size "small") "inline-spinner")
        }}
        data-loading={{@condition}}
        ...attributes
      >
        {{#if @condition}}
          <div class="spinner {{@size}}"></div>
        {{else}}
          {{yield}}
        {{/if}}
      </div>
    </PluginOutlet>
  </template>;

export default DConditionalLoadingSpinner;
