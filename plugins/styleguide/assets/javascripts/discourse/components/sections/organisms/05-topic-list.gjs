import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicListExample from "../../examples/organisms/topic-list";
import topicListSource from "../../examples/organisms/topic-list?source=file";
import TopicListWithoutPostersExample from "../../examples/organisms/topic-list-without-posters";
import topicListWithoutPostersSource from "../../examples/organisms/topic-list-without-posters?source=file";

export default <template>
  <StyleguideExample @code={{topicListSource}} @title="<TopicList>">
    <TopicListExample @topics={{@dummy.topics}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{topicListWithoutPostersSource}}
    @title="<TopicList> - hide posters"
  >
    <TopicListWithoutPostersExample @topics={{@dummy.topics}} />
  </StyleguideExample>
</template>
