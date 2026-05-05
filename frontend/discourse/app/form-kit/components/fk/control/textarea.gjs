import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { trustHTML } from "@ember/template";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";

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

function pixelStyle(property, value) {
  const pixels = pixelValue(value);

  if (pixels === undefined) {
    return;
  }

  return `${property}: ${escapeExpression(pixels)}px`;
}

function numericStyleValue(style, property) {
  return Number.parseFloat(style[property]) || 0;
}

function borderBoxAdjustment(element) {
  const style = getComputedStyle(element);

  if (style.boxSizing !== "border-box") {
    return 0;
  }

  return (
    numericStyleValue(style, "borderTopWidth") +
    numericStyleValue(style, "borderBottomWidth")
  );
}

export default class FKControlTextarea extends FKBaseControl {
  static controlType = "textarea";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
    this.resize(event.target);
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

  @action
  resize(element) {
    if (!this.args.autoResize) {
      return;
    }

    element.style.height = "auto";

    let height = Math.ceil(element.scrollHeight + borderBoxAdjustment(element));
    const minHeight = pixelValue(this.args.minHeight);
    const maxHeight = pixelValue(this.args.maxHeight);

    if (minHeight !== undefined) {
      height = Math.max(height, minHeight);
    }

    if (maxHeight !== undefined) {
      height = Math.min(height, maxHeight);
    }

    element.style.height = `${height}px`;
  }

  get style() {
    const styles = [
      pixelStyle("height", this.args.height),
      pixelStyle("min-height", this.args.minHeight),
      pixelStyle("max-height", this.args.maxHeight),
    ].filter(Boolean);

    if (!styles.length) {
      return;
    }

    return trustHTML(styles.join("; "));
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
      {{didInsert this.resize}}
      {{didUpdate
        this.resize
        @field.value
        @autoResize
        @height
        @minHeight
        @maxHeight
      }}
      {{on "input" this.handleInput}}
      {{on "keydown" this.onKeyDown}}
    />
  </template>
}
