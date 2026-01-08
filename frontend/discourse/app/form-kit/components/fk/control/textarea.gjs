import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlTextarea extends Component {
  static controlType = "textarea";

  resizeObserver = modifierFn((element) => {
    const observer = new ResizeObserver(() => {
      this.args.onControlWidthChange?.(element.offsetWidth);
    });

    observer.observe(element);

    return () => {
      observer.disconnect();
    };
  });

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

    return htmlSafe(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <textarea
      class={{concatClass
        "form-kit__control-textarea"
        (if @noResize "--no-resize")
      }}
      style={{this.style}}
      disabled={{@field.disabled}}
      value={{@field.value}}
      ...attributes
      {{this.resizeObserver}}
      {{on "input" this.handleInput}}
      {{on "keydown" this.onKeyDown}}
    />
  </template>
}
