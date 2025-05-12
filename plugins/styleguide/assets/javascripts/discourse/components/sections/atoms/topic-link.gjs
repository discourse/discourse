import topicLink from "discourse/helpers/topic-link";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicLink = <template>
  <StyleguideExample @title="topic-link">
    {{topicLink @dummy.topic}}
  </StyleguideExample>
</template>;

export default TopicLink;
