import TopicTimerInfo from "discourse/components/topic-timer-info";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicTimerInfo0 = <template>
  <StyleguideExample @title="<TopicTimerInfo>">
    <TopicTimerInfo @statusType="reminder" @executeAt={{@dummy.soon}} />
  </StyleguideExample>
</template>;

export default TopicTimerInfo0;
