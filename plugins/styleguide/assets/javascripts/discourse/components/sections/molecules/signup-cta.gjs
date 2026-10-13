import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SignupCtaExample from "../../examples/molecules/signup-cta";
import signupCtaSource from "../../examples/molecules/signup-cta?source=file";

export default <template>
  <StyleguideExample @code={{signupCtaSource}} @title="<SignupCta>">
    <SignupCtaExample />
  </StyleguideExample>
</template>
