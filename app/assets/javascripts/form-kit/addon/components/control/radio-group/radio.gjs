import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FkLabel from "form-kit/components/label";
import uniqueId from "discourse/helpers/unique-id";

export default class FkControlRadioGroupRadio extends Component {
  <template>
    {{#let (uniqueId) as |uuid|}}
      <div class="d-form-field d-form-radio">
        <FkLabel @fieldId={{uuid}} class="d-form-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{@value}}
            checked={{@checked}}
            id={{uuid}}
            class="d-form-radio__input"
            ...attributes
            {{on "change" (fn @setValue @value)}}
          />
          {{@label}}
        </FkLabel>
      </div>
    {{/let}}
  </template>
}
