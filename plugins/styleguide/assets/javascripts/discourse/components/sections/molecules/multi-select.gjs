import MultiSelectExample from "../../examples/molecules/multi-select";
import multiSelectSource from "../../examples/molecules/multi-select?source=file";
import StyleguideComponent from "../../styleguide/component";
import StyleguideExample from "../../styleguide-example";

export default <template>
  <StyleguideExample @title="<DMultiSelect />" @code={{multiSelectSource}}>
    <StyleguideComponent @tag="d-multi-select component">
      <:sample>
        <MultiSelectExample />
      </:sample>
    </StyleguideComponent>
  </StyleguideExample>
</template>
