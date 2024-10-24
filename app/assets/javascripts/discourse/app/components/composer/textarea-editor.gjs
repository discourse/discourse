import { getOwner } from "@ember/owner";
import DTextarea from "discourse/components/d-textarea";
import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

export default class TextareaEditor extends Component {
  textarea;

  #handleSmartListAutocomplete = false;

  registerTextarea = modifier((textarea) => {
    this.textManipulation = new TextareaTextManipulation(getOwner(this), {
      markdownOptions: this.args.markdownOptions,
      textarea,
    });

    this.args.onSetup(this.textManipulation);

    this.setupSmartList();

    return () => {
      this.destroySmartList();
    };
  });

  onInputSmartList() {
    if (this.#handleSmartListAutocomplete) {
      this.textManipulation.maybeContinueList();
    }
    this.#handleSmartListAutocomplete = false;
  }

  onBeforeInputSmartList(event) {
    // This inputType is much more consistently fired in `beforeinput`
    // rather than `input`.
    this.#handleSmartListAutocomplete = event.inputType === "insertLineBreak";
  }

  setupSmartList() {
    // These must be bound manually because itsatrap does not support
    // beforeinput or input events.
    //
    // beforeinput is better used to detect line breaks because it is
    // fired before the actual value of the textarea is changed,
    // and sometimes in the input event no `insertLineBreak` event type
    // is fired.
    //
    // c.f. https://developer.mozilla.org/en-US/docs/Web/API/Element/beforeinput_event

    this.textarea.addEventListener("beforeinput", this.onBeforeInputSmartList);
    this.textarea.addEventListener("input", this.onInputSmartList);
  }

  destroySmartList() {
    this.textarea.removeEventListener(
      "beforeinput",
      this.onBeforeInputSmartList
    );
    this.textarea.removeEventListener("input", this.onInputSmartList);
  }

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
