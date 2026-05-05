import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import element from "discourse/helpers/element";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlTextarea extends FKBaseControl {
  static controlType = "textarea";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
  }

  /**
   * Handles keyboard shortcuts in the textarea.
   *
   * @param {KeyboardEvent} event - Keyboard event
   */
  @action
  onKeyDown(event) {
    // Ctrl/Cmd + Enter to submit
    if (
      (event.ctrlKey || event.metaKey) &&
      event.key === "Enter" &&
      !event.repeat
    ) {
      event.preventDefault();
      event.target.form?.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true })
      );
    }
  }

  get style() {
    if (!this.args.height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(this.args.height)}px`);
  }

  get textareaElement() {
    return this.args.autoResize ? ExpandingTextArea : element("textarea");
  }

  <template>
    <this.textareaElement
      {{on "input" this.handleInput}}
      {{on "keydown" this.onKeyDown}}
      style={{this.style}}
      disabled={{@field.disabled}}
      value={{@field.value}}
      id={{@field.id}}
      name={{@field.name}}
      aria-invalid={{if @field.error "true"}}
      aria-describedby={{if @field.error @field.errorId}}
      class="form-kit__control-textarea"
      ...attributes
    />
  </template>
}
