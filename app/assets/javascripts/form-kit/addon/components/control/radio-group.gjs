import { hash } from "@ember/helper";
import FKErrors from "form-kit/components/errors";
import FKText from "form-kit/components/text";
import FKControlRadioGroupRadio from "./radio-group/radio";

const FKControlRadioGroup = <template>
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
        Radio=(component FKControlRadioGroupRadio name=@name setValue=@setValue)
      )
    }}

    <FKErrors @errors={{@errors}} />
  </fieldset>
</template>;

export default FKControlRadioGroup;
