import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const TYPES = {
  text: "text",
  password: "password",
};

export default class FKControlInput extends Component {
  static controlType = "password";

  @tracked type = TYPES.password;
  @tracked isFocused = false;

  focusState = modifierFn((element) => {
    const focusInHandler = () => {
      this.isFocused = true;
    };
    const focusOutHandler = () => {
      this.isFocused = false;
    };

    element.addEventListener("focusin", focusInHandler);
    element.addEventListener("focusout", focusOutHandler);

    return () => {
      element.removeEventListener("focusin", focusInHandler);
      element.removeEventListener("focusout", focusOutHandler);
    };
  });

  get iconForType() {
    return this.type === TYPES.password ? "far-eye" : "far-eye-slash";
  }

  @action
  handleInput(event) {
    const value = event.target.value === "" ? undefined : event.target.value;
    this.args.field.set(value);
  }

  @action
  toggleVisibility() {
    this.type = this.type === TYPES.password ? TYPES.text : TYPES.password;
  }

  <template>
    <div
      class={{concatClass
        "form-kit__control-password-wrapper"
        (if this.isFocused "is-focused")
      }}
    >
      <input
        type={{this.type}}
        value={{@field.value}}
        class="form-kit__control-password"
        disabled={{@field.disabled}}
        ...attributes
        {{on "input" this.handleInput}}
        {{this.focusState}}
      />

      <DButton
        class="btn-transparent form-kit__control-password-toggle"
        @action={{this.toggleVisibility}}
        @icon={{this.iconForType}}
        role="switch"
        aria-checked={{eq this.type TYPES.text}}
      />
    </div>
  </template>
}
