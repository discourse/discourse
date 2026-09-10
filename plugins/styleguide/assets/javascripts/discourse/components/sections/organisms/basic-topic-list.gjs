import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import BasicTopicListExample from "../../examples/organisms/basic-topic-list";
import basicTopicListSource from "../../examples/organisms/basic-topic-list?source=file";

export default <template>
  <StyleguideExample @code={{basicTopicListSource}} @title="<BasicTopicList>">
    <BasicTopicListExample @topics={{@dummy.topics}} />
  </StyleguideExample>
</template>
