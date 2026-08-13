import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import DragAndDropExample from "../../examples/molecules/drag-and-drop";
import dragAndDropSource from "../../examples/molecules/drag-and-drop?source=file";

export default <template>
  <StyleguideExample
    @title={{i18n "styleguide.sections.drag_and_drop.title"}}
    @code={{dragAndDropSource}}
  >
    <DragAndDropExample />
  </StyleguideExample>
</template>
