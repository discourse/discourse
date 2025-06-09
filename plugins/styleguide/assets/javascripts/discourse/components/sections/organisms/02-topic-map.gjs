import TopicMap from "discourse/components/topic-map";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicMapOrganism = <template>
  <StyleguideExample @title="topic-map">
    <TopicMap
      @model={{@dummy.postModel}}
      @topicDetails={{@dummy.postModel.topic.details}}
    />
  </StyleguideExample>
</template>;

export default TopicMapOrganism;
