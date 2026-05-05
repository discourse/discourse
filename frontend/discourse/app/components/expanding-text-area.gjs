import { on } from "@ember/modifier";
import autoFocus from "discourse/modifiers/auto-focus";
import autoResizeTextarea from "discourse/modifiers/auto-resize-textarea";

const ExpandingTextArea = <template>
  <textarea
    {{autoResizeTextarea
      manageOverflow=true
      observeFocus=true
      observeInput=true
      observePlaceholder=true
      observeWindow=true
      value=@value
    }}
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
</template>;

export default ExpandingTextArea;
