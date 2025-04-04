import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicMap from "discourse/components/topic-map";
const 02TopicMap = <template><StyleguideExample @title="topic-map">
  <TopicMap @model={{@dummy.postModel}} @topicDetails={{@dummy.postModel.topic.details}} />
</StyleguideExample></template>;
export default 02TopicMap;