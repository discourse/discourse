import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormErrors from "form-kit/components/errors";
import FkText from "form-kit/components/text";
import uniqueId from "discourse/helpers/unique-id";
import FKControlCheckboxGroupCheckbox from "./checkbox-group/checkbox";

export default class FKControlCheckboxGroup extends Component {
  <template>
    {{#let (uniqueId) as |labelId|}}
      <fieldset
        aria-invalid={{if @invalid "true"}}
        aria-describedby={{if @invalid @errorId}}
        class="d-form__checbox-group"
        ...attributes
      >
        {{#if @title}}
          <legend class="d-form__checkbox-group__title">{{@title}}</legend>
        {{/if}}

        {{#if @subtitle}}
          <FkText class="d-form__checkbox-group__subtitle">
            {{@subtitle}}
          </FkText>
        {{/if}}

        {{yield
          (hash
            Checkbox=(component
              FKControlCheckboxGroupCheckbox name=@name setValue=@setValue
            )
          )
        }}

        <FormErrors @errors={{@errors}} />
      </fieldset>
    {{/let}}
  </template>
}
