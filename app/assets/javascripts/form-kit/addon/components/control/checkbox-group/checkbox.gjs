import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "form-kit/components/label";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";

export default class FKControlCheckboxGroupCheckbox extends Component {
  @action
  handleInput() {
    this.args.setValue(!this.args.value);
  }

  <template>
    --------

    {{#let (uniqueId) as |uuid|}}
      <div class="d-form-field d-form-radio">
        <FKLabel @fieldId={{uuid}} class="d-form-radio__label">
          <input
            type="checkbox"
            checked={{eq @value true}}
            class="d-form__control-checkbox"
            ...attributes
            {{on "change" this.handleInput}}
          />
          {{@label}}
        </FKLabel>
      </div>
    {{/let}}
  </template>
}
