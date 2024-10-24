// naming is hard; please help
import { getOwner } from "@ember/owner";
import DTextarea from "discourse/components/d-textarea";
import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

export default class TextareaEditor extends Component {
  textarea;

  registerTextarea = modifier((textarea) => {
    console.log(this.args.markdownOptions);
    this.textManipulation = new TextareaTextManipulation(getOwner(this), {
      markdownOptions: this.args.markdownOptions,
      textarea,
    });
    this.args.onSetup(this.textManipulation);

    return () => {};
  });

  <template>
    <DTextarea
      @autocomplete="off"
      @value={{@value}}
      @placeholder={{@placeholder}}
      @aria-label={{@placeholder}}
      @disabled={{@disabled}}
      @input={{@change}}
      @focusIn={{@focusIn}}
      @focusOut={{@focusOut}}
      class="d-editor-input"
      @id={{@id}}
      {{this.registerTextarea}}
    />
  </template>
}
