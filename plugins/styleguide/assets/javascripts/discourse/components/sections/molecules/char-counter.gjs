import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import CharCounter from "discourse/components/char-counter";
import withEventValue from "discourse/helpers/with-event-value";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const CharCounterMolecule = <template>
  <StyleguideExample @title="<CharCounter>">
    <CharCounter @max="50" @value={{@dummy.charCounterContent}}>
      <textarea
        {{on "input" (withEventValue (fn (mut @dummy.charCounterContent)))}}
        class="styleguide--char-counter"
      ></textarea>
    </CharCounter>
  </StyleguideExample>
</template>;

export default CharCounterMolecule;
