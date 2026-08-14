import ReorderableListBasicExample from "../../examples/molecules/reorderable-list/basic";
import reorderableListBasicSource from "../../examples/molecules/reorderable-list/basic?source=file";
import ReorderableListCreateExample from "../../examples/molecules/reorderable-list/create";
import reorderableListCreateSource from "../../examples/molecules/reorderable-list/create?source=file";
import ReorderableListCrossListExample from "../../examples/molecules/reorderable-list/cross-list";
import reorderableListCrossListSource from "../../examples/molecules/reorderable-list/cross-list?source=file";
import ReorderableListGrabExample from "../../examples/molecules/reorderable-list/grab";
import reorderableListGrabSource from "../../examples/molecules/reorderable-list/grab?source=file";
import ReorderableListPoliciesExample from "../../examples/molecules/reorderable-list/policies";
import reorderableListPoliciesSource from "../../examples/molecules/reorderable-list/policies?source=file";
import StyleguideExample from "../../styleguide-example";

export default <template>
  <StyleguideExample
    @title="<DReorderableList>"
    @code={{reorderableListBasicSource}}
  >
    <ReorderableListBasicExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<DReorderableList> - pinned row, wrap, inline revealed arrows"
    @code={{reorderableListPoliciesSource}}
  >
    <ReorderableListPoliciesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<DReorderableList> - grab keyboard mode"
    @code={{reorderableListGrabSource}}
  >
    <ReorderableListGrabExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<DReorderableListGroup> - cross-list drag"
    @code={{reorderableListCrossListSource}}
  >
    <ReorderableListCrossListExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<DReorderableList> - create affordance"
    @code={{reorderableListCreateSource}}
  >
    <ReorderableListCreateExample />
  </StyleguideExample>
</template>
