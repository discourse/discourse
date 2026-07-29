import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import DCharCounter from "discourse/ui-kit/d-char-counter";

export default <template>
  <DCharCounter @max="50" @value={{@dummy.charCounterContent}}>
    <textarea
      {{on "input" (withEventValue (fn (mut @dummy.charCounterContent)))}}
      class="styleguide--char-counter"
    ></textarea>
  </DCharCounter>
</template>
