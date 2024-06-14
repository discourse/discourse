import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/label";
import FKMeta from "discourse/form-kit/components/meta";
import concatClass from "discourse/helpers/concat-class";

export default class FKControlCheckbox extends Component {
  @action
  handleInput() {
    this.args.set(!this.args.value);
  }

  <template>
    <div
      class={{concatClass
        "form-kit__field"
        "form-kit__field-checkbox"
        (if @field.disabled "--disabled")
      }}
    >
      <FKLabel class="form-kit__control-checkbox__label">
        <input
          type="checkbox"
          checked={{eq @value true}}
          class="form-kit__control-checkbox"
          disabled={{@field.disabled}}
          ...attributes
          {{on "change" this.handleInput}}
        />
        {{@label}}
      </FKLabel>

      <FKMeta @value={{@value}} @field={{@field}} @errors={{@errors}} />
    </div>
  </template>
}
