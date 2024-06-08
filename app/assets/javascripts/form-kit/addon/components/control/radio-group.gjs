import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKErrors from "form-kit/components/errors";
import FKText from "form-kit/components/text";
import uniqueId from "discourse/helpers/unique-id";
import FkControlRadioGroupRadio from "./radio-group/radio";

export default class FKControlRadioGroup extends Component {
  <template>
    {{#let (uniqueId) as |labelId|}}
      <fieldset
        aria-invalid={{if @invalid "true"}}
        aria-describedby={{if @invalid @errorId}}
        class="d-form__radio-group"
        ...attributes
      >
        {{#if @title}}
          <legend class="d-form__radio-group__legend">{{@title}}</legend>
        {{/if}}

        {{#if @subtitle}}
          <FKText class="d-form__radio-group__subtitle">
            {{@subtitle}}
          </FKText>
        {{/if}}

        {{yield
          (hash
            Radio=(component
              FkControlRadioGroupRadio name=@name setValue=@setValue
            )
          )
        }}

        <FKErrors @errors={{@errors}} />
      </fieldset>
    {{/let}}
  </template>
}
