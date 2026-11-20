import Component from "@glimmer/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

interface DCharCounterSignature {
  Args: {
    /** The text whose characters are counted. */
    value?: string | null;

    /**
     * The maximum number of characters. Above it, the counter is marked as exceeded
     * and screen readers announce it.
     */
    max: number | string;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** The field whose text is counted, rendered above the ratio. */
    default: [];
  };
}

export default class DCharCounter extends Component<DCharCounterSignature> {
  /**
   * The number of characters in the value.
   *
   * @returns The length of `@value`, or 0 without a value.
   */
  get characterCount() {
    return this.args.value?.length ?? 0;
  }

  <template>
    <div
      class={{dConcatClass
        "char-counter"
        (if (gt this.characterCount @max) "exceeded")
      }}
      ...attributes
    >
      {{yield}}
      <small class="char-counter__ratio">
        {{this.characterCount}}/{{@max}}
      </small>
      <span aria-live="polite" class="sr-only">
        {{if (gt this.characterCount @max) (i18n "char_counter.exceeded")}}
      </span>
    </div>
  </template>
}
