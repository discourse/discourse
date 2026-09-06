import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SpinnerRegularExample from "../../examples/atoms/spinners/regular";
import spinnerRegularSource from "../../examples/atoms/spinners/regular?source=template";
import SpinnerSmallExample from "../../examples/atoms/spinners/small";
import spinnerSmallSource from "../../examples/atoms/spinners/small?source=template";

export default <template>
  <StyleguideExample @title="spinner - small" @code={{spinnerSmallSource}}>
    <SpinnerSmallExample />
  </StyleguideExample>

  <StyleguideExample @title="spinner - regular" @code={{spinnerRegularSource}}>
    <SpinnerRegularExample />
  </StyleguideExample>
</template>
