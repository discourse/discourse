import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FormErrors from "form-kit/components/form/errors";
import FkText from "form-kit/components/form/text";
import FkLabel from "form-kit/components/label";
import uniqueId from "discourse/helpers/unique-id";
import FkControlRadioGroupRadio from "./radio-group/radio";

export default class FkControlRadioGroup extends Component {
  <template>
    {{#let (uniqueId) as |labelId|}}
      <fieldset
        aria-invalid={{if @invalid "true"}}
        aria-describedby={{if @invalid @errorId}}
        class="d-form-radio-group"
        ...attributes
      >
        {{#if @legend}}
          <legend class="d-form-radio-group__legend">{{@legend}}</legend>
        {{/if}}

        {{#if @help}}
          <FkText>
            {{@help}}
          </FkText>
        {{/if}}

        {{yield
          (hash
            Radio=(component
              FkControlRadioGroupRadio name=@name setValue=@setValue
            )
          )
        }}

        <FormErrors @errors={{@errors}} />
      </fieldset>
    {{/let}}
  </template>
}
