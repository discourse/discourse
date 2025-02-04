import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import { modifier } from "ember-modifier";
import DTextarea from "discourse/components/d-textarea";
import { bind } from "discourse/lib/decorators";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

export default class TextareaEditor extends Component {
  @service currentUser;

  textarea;

  registerTextarea = modifier((textarea) => {
    this.textarea = textarea;
    this.#itsatrap = new ItsATrap(textarea);

    this.textManipulation = new TextareaTextManipulation(getOwner(this), {
      markdownOptions: this.args.markdownOptions,
      textarea,
    });

    for (const [key, callback] of Object.entries(this.args.keymap)) {
      this.#itsatrap.bind(key, callback);
    }

    const destructor = this.args.onSetup(this.textManipulation);

    this.setupSmartList();

    return () => {
      this.destroySmartList();
      destructor?.();
      this.#itsatrap?.destroy();
      this.#itsatrap = null;
    };
  });

  #itsatrap;
  #handleSmartListAutocomplete = false;
  #shiftPressed = false;

  @bind
  onInputSmartList() {
    if (this.#handleSmartListAutocomplete) {
      this.textManipulation.maybeContinueList();
    }
    this.#handleSmartListAutocomplete = false;
  }

  @bind
  onBeforeInputSmartListShiftDetect(event) {
    this.#shiftPressed = event.shiftKey;
  }

  @bind
  onBeforeInputSmartList(event) {
    // This inputType is much more consistently fired in `beforeinput`
    // rather than `input`.
    if (!this.#shiftPressed) {
      this.#handleSmartListAutocomplete = event.inputType === "insertLineBreak";
    }
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
    if (this.currentUser.user_option.enable_smart_lists) {
      this.textarea.addEventListener(
        "beforeinput",
        this.onBeforeInputSmartList
      );
      this.textarea.addEventListener(
        "keydown",
        this.onBeforeInputSmartListShiftDetect
      );
      this.textarea.addEventListener("input", this.onInputSmartList);
    }
  }

  destroySmartList() {
    if (this.currentUser.user_option.enable_smart_lists) {
      this.textarea.removeEventListener(
        "beforeinput",
        this.onBeforeInputSmartList
      );
      this.textarea.removeEventListener(
        "keydown",
        this.onBeforeInputSmartListShiftDetect
      );
      this.textarea.removeEventListener("input", this.onInputSmartList);
    }
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
