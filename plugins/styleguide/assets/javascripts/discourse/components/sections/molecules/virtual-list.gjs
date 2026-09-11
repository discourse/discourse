import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import VirtualListExample from "../../examples/molecules/virtual-list";
import virtualListSource from "../../examples/molecules/virtual-list?source=file";
import VirtualListVariableExample from "../../examples/molecules/virtual-list-variable";
import virtualListVariableSource from "../../examples/molecules/virtual-list-variable?source=file";

export default <template>
  <StyleguideExample
    @code={{virtualListSource}}
    @description="Thousands of rows, of which only the visible window plus overscan is in the DOM. The list opens already scrolled to the selected row."
    @title="<DVirtualList> — pinned rows and an initial selection"
  >
    <:tryThis>
      Scroll far away from the selection and inspect the DOM: the selected row
      keeps its
      <code>[data-index]</code>
      element mounted, so a cursor pointing at it never dangles.
    </:tryThis>
    <:default>
      <div class="styleguide-virtual-list">
        <VirtualListExample />
      </div>
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @code={{virtualListVariableSource}}
    @description="Rows whose real heights differ against a single estimate, so each re-measures as it enters the window and the total settles as you scroll. Rows are placed individually rather than laid out in flow, so a correction moves one row instead of reflowing the rest."
    @title="<DVirtualList> — variable-height rows"
  >
    <div class="styleguide-virtual-list styleguide-virtual-list--tall">
      <VirtualListVariableExample />
    </div>
  </StyleguideExample>
</template>
