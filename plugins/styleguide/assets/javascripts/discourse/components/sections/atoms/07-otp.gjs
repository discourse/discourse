import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CallbacksExample from "../../examples/atoms/otp/callbacks";
import callbacksSource from "../../examples/atoms/otp/callbacks?source=file";
import SlotsExample from "../../examples/atoms/otp/slots";
import slotsSource from "../../examples/atoms/otp/slots?source=file";

export default <template>
  <StyleguideExample @code={{callbacksSource}} @title="DOtp">
    <CallbacksExample />
  </StyleguideExample>

  <StyleguideExample @code={{slotsSource}} @title="DOtp @slots={{4}}">
    <SlotsExample />
  </StyleguideExample>
</template>
