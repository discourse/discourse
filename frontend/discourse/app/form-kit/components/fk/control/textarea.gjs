import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";
import autoResizeTextarea from "discourse/modifiers/auto-resize-textarea";

function pixelValue(value) {
  if (value === undefined || value === null || value === "") {
    return;
  }

  const number = Number(value);

  if (!Number.isFinite(number)) {
    return;
  }

  return number;
}

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
    const height = pixelValue(this.args.height);

    if (height === undefined) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(height)}px`);
  }

  <template>
    <textarea
      class="form-kit__control-textarea"
      style={{this.style}}
      disabled={{@field.disabled}}
      value={{@field.value}}
      id={{@field.id}}
      name={{@field.name}}
      aria-invalid={{if @field.error "true"}}
      aria-describedby={{if @field.error @field.errorId}}
      ...attributes
      {{autoResizeTextarea
        enabled=(if @autoResize true false)
        observeInput=true
        observeWindow=true
        value=@field.value
      }}
      {{on "input" this.handleInput}}
      {{on "keydown" this.onKeyDown}}
    />
  </template>
}
