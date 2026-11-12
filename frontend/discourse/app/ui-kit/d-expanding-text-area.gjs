import { on } from "@ember/modifier";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

const DExpandingTextArea = <template>
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
      {{(if @input (modifier on "input" @input))}}
    ></textarea>
  </div>
</template>;

export default DExpandingTextArea;
