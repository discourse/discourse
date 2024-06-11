import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "form-kit/components/label";
import uniqueId from "discourse/helpers/unique-id";

export default class FkControlRadioGroupRadio extends Component {
  <template>
    {{#let (uniqueId) as |uuid|}}
      <div class="d-form-field d-form-radio">
        <FKLabel @fieldId={{uuid}} class="d-form__control-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{@value}}
            checked={{@checked}}
            id={{uuid}}
            class="d-form-radio__input"
            disabled={{@disabled}}
            ...attributes
            {{on "change" (fn @setValue @value)}}
          />
          {{@label}}
        </FKLabel>
      </div>
    {{/let}}
  </template>
}
