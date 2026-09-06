import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CallbacksExample from "../../examples/atoms/otp/callbacks";
import callbacksSource from "../../examples/atoms/otp/callbacks?source=file";
import SlotsExample from "../../examples/atoms/otp/slots";
import slotsSource from "../../examples/atoms/otp/slots?source=file";

export default <template>
  <StyleguideExample @title="DOtp" @code={{callbacksSource}}>
    <CallbacksExample />
  </StyleguideExample>

  <StyleguideExample @title="DOtp @slots={{4}}" @code={{slotsSource}}>
    <SlotsExample />
  </StyleguideExample>
</template>
