import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CharCounter from "discourse/components/char-counter";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { fn } from "@ember/helper";
const CharCounter0 = <template><StyleguideExample @title="<CharCounter>">
  <CharCounter @max="50" @value={{@dummy.charCounterContent}}>
    <textarea {{on "input" (withEventValue (fn (mut @dummy.charCounterContent)))}} class="styleguide--char-counter"></textarea>
  </CharCounter>
</StyleguideExample></template>;
export default CharCounter0;