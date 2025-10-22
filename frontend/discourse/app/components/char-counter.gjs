import { gt } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const CharCounter = <template>
  <div
    class={{concatClass "char-counter" (if (gt @value.length @max) "exceeded")}}
    ...attributes
  >
    {{yield}}
    <small class="char-counter__ratio">
      {{@value.length}}/{{@max}}
    </small>
    <span aria-live="polite" class="sr-only">
      {{if (gt @value.length @max) (i18n "char_counter.exceeded")}}
    </span>
  </div>
</template>;

export default CharCounter;
