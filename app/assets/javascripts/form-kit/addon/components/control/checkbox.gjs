import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "form-kit/components/label";
import FKMeta from "form-kit/components/meta";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

export default class FKControlCheckbox extends Component {
  @action
  handleInput() {
    this.args.set(!this.args.value);
  }

  <template>
    <div
      class={{concatClass
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
