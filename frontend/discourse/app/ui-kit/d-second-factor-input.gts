import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DOtp from "discourse/ui-kit/d-otp/index";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

interface DSecondFactorInputSignature {
  Args: {
    /** The second factor method, one of `SECOND_FACTOR_METHODS`. A TOTP code uses slots. */
    secondFactorMethod?: number;

    /** Called with the code as it changes. */
    onChange: (value: string) => void;

    /** Called with the TOTP code once every slot is filled. */
    onFill?: (value: string) => void;
  };

  Element: HTMLInputElement;
}

export default class DSecondFactorInput extends Component<DSecondFactorInputSignature> {
  get isTotp() {
    return this.args.secondFactorMethod === SECOND_FACTOR_METHODS.TOTP;
  }

  <template>
    {{#if this.isTotp}}
      <DOtp
        class="second-factor-token-input"
        ...attributes
        @onChange={{@onChange}}
        @onFill={{@onFill}}
      />
    {{else}}
      <input
        autocapitalize="off"
        autocorrect="off"
        autofocus="autofocus"
        class="second-factor-token-input"
        maxlength="32"
        type="text"
        ...attributes
        {{on "input" (withEventValue @onChange)}}
        {{dAutoFocus}}
      />
    {{/if}}
  </template>
}
