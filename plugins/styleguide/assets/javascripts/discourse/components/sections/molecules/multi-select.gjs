import MultiSelectExample from "../../examples/molecules/multi-select.gjs";
import multiSelectSource from "../../examples/molecules/multi-select?source=file";
import StyleguideComponent from "../../styleguide/component.gjs";
import StyleguideExample from "../../styleguide-example.gjs";

export default <template>
  <StyleguideExample @code={{multiSelectSource}} @title="<DMultiSelect />">
    <StyleguideComponent @tag="d-multi-select component">
      <:sample>
        <MultiSelectExample />
      </:sample>
    </StyleguideComponent>
  </StyleguideExample>
</template>
