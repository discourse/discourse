import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import dElement from "discourse/ui-kit/helpers/d-element";

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
    return this.args.autoResize ? DExpandingTextArea : dElement("textarea");
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
      aria-describedby={{@field.describedBy}}
      class="form-kit__control-textarea"
      ...attributes
    />
  </template>
}
