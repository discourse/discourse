import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SpinnerRegularExample from "../../examples/atoms/spinners/regular";
import spinnerRegularSource from "../../examples/atoms/spinners/regular?source=template";
import SpinnerSmallExample from "../../examples/atoms/spinners/small";
import spinnerSmallSource from "../../examples/atoms/spinners/small?source=template";

export default <template>
  <StyleguideExample @code={{spinnerSmallSource}} @title="spinner - small">
    <SpinnerSmallExample />
  </StyleguideExample>

  <StyleguideExample @code={{spinnerRegularSource}} @title="spinner - regular">
    <SpinnerRegularExample />
  </StyleguideExample>
</template>
