import SuggestedTopics from "discourse/components/suggested-topics";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const SuggestedTopicsOrganism = <template>
  <StyleguideExample @title="<SuggestedTopics>">
    <SuggestedTopics @topic={{@dummy.topic}} />
  </StyleguideExample>
</template>;

export default SuggestedTopicsOrganism;
