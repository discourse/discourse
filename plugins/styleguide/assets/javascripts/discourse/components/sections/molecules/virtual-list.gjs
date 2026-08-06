import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import VirtualListExample from "../../examples/molecules/virtual-list";
import virtualListSource from "../../examples/molecules/virtual-list?source=file";
import VirtualListVariableExample from "../../examples/molecules/virtual-list-variable";
import virtualListVariableSource from "../../examples/molecules/virtual-list-variable?source=file";

export default <template>
  <StyleguideExample
    @title="<DVirtualList> — pinned rows and an initial selection"
    @code={{virtualListSource}}
  >
    <div class="styleguide-virtual-list">
      <p class="styleguide-virtual-list__note">
        Thousands of rows, of which only the visible window plus overscan is in
        the DOM. The list opens already scrolled to the selected row. Scroll far
        away from it and inspect the DOM: the selected row keeps its
        <code>[data-index]</code>
        element mounted, so a keyboard cursor pointing at it never dangles.
      </p>

      <VirtualListExample />
    </div>
  </StyleguideExample>

  <StyleguideExample
    @title="<DVirtualList> — variable-height rows"
    @code={{virtualListVariableSource}}
  >
    <div class="styleguide-virtual-list styleguide-virtual-list--tall">
      <p class="styleguide-virtual-list__note">
        Rows whose real heights differ against a single estimate, so each one
        re-measures as it enters the window and the total settles as you scroll.
        Rows are placed individually rather than laid out in flow, so a
        correction moves one row instead of reflowing the rest.
      </p>

      <VirtualListVariableExample />
    </div>
  </StyleguideExample>
</template>
