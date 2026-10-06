import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DOtp from "discourse/ui-kit/d-otp";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

export default class DSecondFactorInput extends Component {
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
        pattern="[a-z0-9]{16}"
        type="text"
        ...attributes
        {{on "input" (withEventValue @onChange)}}
        {{dAutoFocus}}
      />
    {{/if}}
  </template>
}
