import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicList from "discourse/components/topic-list";
const 04TopicList = <template><StyleguideExample @title="<TopicList>">
  <TopicList @topics={{@dummy.topics}} @showPosters={{true}} />
</StyleguideExample>

<StyleguideExample @title="<TopicList> - hide posters>">
  <TopicList @topics={{@dummy.topics}} @showPosters={{false}} />
</StyleguideExample></template>;
export default 04TopicList;