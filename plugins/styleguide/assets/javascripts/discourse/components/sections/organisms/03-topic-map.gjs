import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicMapExample from "../../examples/organisms/topic-map";
import topicMapSource from "../../examples/organisms/topic-map?source=file";

export default <template>
  <StyleguideExample @title="topic-map" @code={{topicMapSource}}>
    <TopicMapExample @post={{@dummy.postModel}} />
  </StyleguideExample>
</template>
