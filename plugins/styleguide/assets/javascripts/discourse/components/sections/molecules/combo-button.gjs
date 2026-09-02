import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import ComboButtonExample from "../../examples/molecules/combo-button";
import comboButtonSource from "../../examples/molecules/combo-button?source=file";

export default <template>
  <StyleguideExample @code={{comboButtonSource}} @title="<DComboButton>">
    <ComboButtonExample />
  </StyleguideExample>
</template>
