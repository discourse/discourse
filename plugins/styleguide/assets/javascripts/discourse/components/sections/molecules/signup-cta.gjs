import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SignupCtaExample from "../../examples/molecules/signup-cta";
import signupCtaSource from "../../examples/molecules/signup-cta?source=file";

export default <template>
  <StyleguideExample @title="<SignupCta>" @code={{signupCtaSource}}>
    <SignupCtaExample />
  </StyleguideExample>
</template>
