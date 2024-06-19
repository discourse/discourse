import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKErrors from "discourse/form-kit/components/errors";
import FKText from "discourse/form-kit/components/text";
import FKControlRadioGroupRadio from "./radio-group/radio";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
export default class FKControlRadioGroup extends Component {
  <template>
    <fieldset class="form-kit__radio-group" ...attributes>
      {{#if @title}}
        <legend class="form-kit__radio-group-title">{{@title}}</legend>
      {{/if}}

      {{#if @subtitle}}
        <FKText class="form-kit__radio-group-subtitle">
          {{@subtitle}}
        </FKText>
      {{/if}}

      {{yield
        (hash
          Radio=(component
            FKControlRadioGroupRadio groupValue=@value field=@field
          )
        )
      }}
    </fieldset>

    <FKErrors @errors={{@errors}} />
  </template>
}
