import Component from "@glimmer/component";
import { action } from "@ember/object";
import DOTP from "discourse/components/d-otp";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class OTP extends Component {
  @action
  onFilled(otp) {
    // eslint-disable-next-line no-alert
    alert(`OTP filled: ${otp}`);
  }

  <template>
    <StyleguideExample @title="d-otp">
      <DOTP @onFilled={{this.onFilled}} />
    </StyleguideExample>

    <StyleguideExample @title="4 slots">
      <DOTP @onFilled={{this.onFilled}} @slots={{4}} />
    </StyleguideExample>
  </template>
}
