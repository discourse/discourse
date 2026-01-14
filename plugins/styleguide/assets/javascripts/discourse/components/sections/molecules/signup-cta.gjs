import Component from "@glimmer/component";
import SignupCta from "discourse/components/signup-cta";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class SignupCtaMolecule extends Component {
  signupCtaCode = `<SignupCta />`;

  <template>
    <StyleguideExample @title="<SignupCta>" @code={{this.signupCtaCode}}>
      <SignupCta />
    </StyleguideExample>
  </template>
}
