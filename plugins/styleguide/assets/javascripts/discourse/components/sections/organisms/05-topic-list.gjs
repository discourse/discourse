import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicListExample from "../../examples/organisms/topic-list";
import topicListSource from "../../examples/organisms/topic-list?source=file";
import TopicListWithoutPostersExample from "../../examples/organisms/topic-list-without-posters";
import topicListWithoutPostersSource from "../../examples/organisms/topic-list-without-posters?source=file";

export default <template>
  <StyleguideExample @title="<TopicList>" @code={{topicListSource}}>
    <TopicListExample @topics={{@dummy.topics}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<TopicList> - hide posters"
    @code={{topicListWithoutPostersSource}}
  >
    <TopicListWithoutPostersExample @topics={{@dummy.topics}} />
  </StyleguideExample>
</template>
