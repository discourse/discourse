import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
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

  get style() {
    if (!this.args.height) {
      return;
    }

    return htmlSafe(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <textarea
      class="form-kit__control-textarea"
      style={{this.style}}
      disabled={{@field.disabled}}
      value={{@field.value}}
      ...attributes
      {{this.resizeObserver}}
      {{on "input" this.handleInput}}
    />
  </template>
}
