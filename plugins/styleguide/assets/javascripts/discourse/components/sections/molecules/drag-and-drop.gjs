import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import DragAndDropExample from "../../examples/molecules/drag-and-drop";
import dragAndDropSource from "../../examples/molecules/drag-and-drop?source=file";

export default <template>
  <StyleguideExample @title="Drag and drop" @code={{dragAndDropSource}}>
    <DragAndDropExample />
  </StyleguideExample>
</template>
