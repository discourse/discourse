import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import DOTP from "discourse/components/d-otp";
import withEventValue from "discourse/helpers/with-event-value";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import autoFocus from "discourse/modifiers/auto-focus";

export default class SecondFactorInput extends Component {
  get isTotp() {
    return this.args.secondFactorMethod === SECOND_FACTOR_METHODS.TOTP;
  }

  <template>
    {{#if this.isTotp}}
      <DOTP
        @onFill={{@onFill}}
        @onChange={{@onChange}}
        class="second-factor-token-input"
        ...attributes
      />
    {{else}}
      <input
        type="text"
        pattern="[a-z0-9]{16}"
        maxlength="32"
        autocapitalize="off"
        autocorrect="off"
        autofocus="autofocus"
        class="second-factor-token-input"
        ...attributes
        {{on "input" (withEventValue @onChange)}}
        {{autoFocus}}
      />
    {{/if}}
  </template>
}
