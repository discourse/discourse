import type { TOC } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

export interface DExpandingTextAreaSignature {
  Args: {
    /**
     * The text of the textarea. The wrapper mirrors it so that CSS can grow the
     * textarea to fit.
     */
    value?: string | null;

    /** Whether the textarea takes focus when it renders. */
    autoFocus?: boolean;

    /** Called on every input event. */
    input?: (event: Event) => void;

    /** Deprecated: pass `autocorrect` as an attribute instead. */
    autocorrect?: string;

    /** Deprecated: pass `class` as an attribute instead. */
    class?: string;

    /** Deprecated: pass `maxlength` as an attribute instead. */
    maxlength?: number | string;

    /** Deprecated: pass `name` as an attribute instead. */
    name?: string;

    /** Deprecated: pass `rows` as an attribute instead. */
    rows?: number | string;
  };

  Element: HTMLTextAreaElement;
}

const DExpandingTextArea: TOC<DExpandingTextAreaSignature> = <template>
  <div class="expanding-text-area" data-replicated-value={{@value}}>
    <textarea
      {{! deprecated args: }}
      autocorrect={{@autocorrect}}
      class="--expandable {{@class}}"
      maxlength={{@maxlength}}
      name={{@name}}
      rows={{@rows}}
      value={{@value}}
      ...attributes
      {{(if @autoFocus dAutoFocus)}}
      {{! @glint-expect-error: a conditional modifier with bound arguments can't be typed }}
      {{(if @input (modifier on "input" @input))}}
    ></textarea>
  </div>
</template>;

export default DExpandingTextArea;
