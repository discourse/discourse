import { on } from "@ember/modifier";
import autosize from "autosize";
import { modifier as modifierFn } from "ember-modifier";
import autoFocus from "discourse/modifiers/auto-focus";

const resize = modifierFn((element) => {
  autosize(element);
  return () => autosize.destroy(element);
});

const ExpandingTextArea = <template>
  <textarea
    {{autoFocus}}
    {{resize}}
    {{! deprecated args: }}
    autocorrect={{@autocorrect}}
    class={{@class}}
    maxlength={{@maxlength}}
    name={{@name}}
    rows={{@rows}}
    value={{@value}}
    {{(if @input (modifier on "input" @input))}}
    ...attributes
  ></textarea>
</template>;

export default ExpandingTextArea;
