import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import topicLink from "discourse/helpers/topic-link";
const TopicLink = <template><StyleguideExample @title="topic-link">
  {{topicLink @dummy.topic}}
</StyleguideExample></template>;
export default TopicLink;