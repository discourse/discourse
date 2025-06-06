import SuggestedTopics from "discourse/components/suggested-topics";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const SuggestedTopics0 = <template>
  <StyleguideExample @title="<SuggestedTopics>">
    <SuggestedTopics @topic={{@dummy.topic}} />
  </StyleguideExample>
</template>;

export default SuggestedTopics0;
