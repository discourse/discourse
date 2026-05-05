import { on } from "@ember/modifier";
import autoFocus from "discourse/modifiers/auto-focus";

const ExpandingTextArea = <template>
  <div class="expanding-text-area" data-replicated-value={{@value}}>
    <textarea
      {{(if @autoFocus autoFocus)}}
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
  </div>
</template>;

export default ExpandingTextArea;
