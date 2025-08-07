import MoreTopics from "discourse/components/more-topics";
import RelatedMessages from "discourse/components/related-messages";
import SuggestedTopics from "discourse/components/suggested-topics";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const MoreTopicsOrganism = <template>
  <StyleguideExample @title="<SuggestedTopics>">
    <SuggestedTopics @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample @title="<RelatedMessages>">
    <RelatedMessages @topic={{@dummy.pmTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="<MoreTopics> - with tabs">
    <MoreTopics @topic={{@dummy.pmTopic}} />
  </StyleguideExample>
</template>;

export default MoreTopicsOrganism;
