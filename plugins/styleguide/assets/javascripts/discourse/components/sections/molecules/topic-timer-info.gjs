import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicTimerInfoExample from "../../examples/molecules/topic-timer-info";
import topicTimerInfoSource from "../../examples/molecules/topic-timer-info?source=file";

export default <template>
  <StyleguideExample @code={{topicTimerInfoSource}} @title="<TopicTimerInfo>">
    <TopicTimerInfoExample />
  </StyleguideExample>
</template>
