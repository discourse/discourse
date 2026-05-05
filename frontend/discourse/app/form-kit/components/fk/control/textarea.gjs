import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import concatClass from "discourse/helpers/concat-class";
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

  get wrapperElement() {
    return element(this.args.autoResize ? "div" : "");
  }

  <template>
    <this.wrapperElement
      class="form-kit__control-textarea-wrap"
      data-replicated-value={{@field.value}}
    >
      <textarea
        class={{concatClass
          "form-kit__control-textarea"
          (if @autoResize "form-kit__control-textarea--auto-resize")
        }}
        style={{this.style}}
        disabled={{@field.disabled}}
        value={{@field.value}}
        id={{@field.id}}
        name={{@field.name}}
        aria-invalid={{if @field.error "true"}}
        aria-describedby={{if @field.error @field.errorId}}
        ...attributes
        {{on "input" this.handleInput}}
        {{on "keydown" this.onKeyDown}}
      />
    </this.wrapperElement>
  </template>
}
