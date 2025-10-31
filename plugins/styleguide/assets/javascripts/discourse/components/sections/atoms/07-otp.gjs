import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DOTP from "discourse/components/d-otp";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class OTP extends Component {
  @tracked filledOutput;
  @tracked changedOutput;

  @action
  filled(otp) {
    this.filledOutput = `filled: ${otp}`;
  }

  @action
  changed(otp) {
    this.filledOutput = null;

    if (otp.length) {
      this.changedOutput = `changed: ${otp}`;
    } else {
      this.changedOutput = null;
    }
  }

  <template>
    <StyleguideExample @title="d-otp">
      <DOTP @onFill={{this.filled}} @onChange={{this.changed}} />

      {{#if this.changedOutput}}
        <output>
          {{#if this.changedOutput}}
            <p>{{this.changedOutput}}</p>
          {{/if}}

          {{#if this.filledOutput}}
            <p>{{this.filledOutput}}</p>
          {{/if}}
        </output>
      {{/if}}
    </StyleguideExample>

    <StyleguideExample @title="@slots={{4}}">
      <DOTP @slots={{4}} />
    </StyleguideExample>
  </template>
}
