import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SegmentedControlExample from "../../examples/molecules/segmented-control.gjs";
import segmentedControlSource from "../../examples/molecules/segmented-control?source=file";

export default <template>
  <StyleguideExample
    @code={{segmentedControlSource}}
    @title="<DSegmentedControl>"
  >
    <SegmentedControlExample />
  </StyleguideExample>
</template>
