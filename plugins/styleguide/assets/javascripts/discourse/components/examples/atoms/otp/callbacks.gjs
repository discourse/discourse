import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DOtp from "discourse/ui-kit/d-otp";

export default class OtpCallbacksExample extends Component {
  @tracked changedOutput;
  @tracked filledOutput;

  @action
  changed(otp) {
    this.filledOutput = null;
    this.changedOutput = otp.length ? `changed: ${otp}` : null;
  }

  @action
  filled(otp) {
    this.filledOutput = `filled: ${otp}`;
  }

  <template>
    <DOtp @onFill={{this.filled}} @onChange={{this.changed}} />

    {{#if this.changedOutput}}
      <output>
        <p>{{this.changedOutput}}</p>

        {{#if this.filledOutput}}
          <p>{{this.filledOutput}}</p>
        {{/if}}
      </output>
    {{/if}}
  </template>
}
