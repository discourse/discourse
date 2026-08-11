import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicNotificationsButtonExample from "../../examples/molecules/topic-notifications-button";
import topicNotificationsButtonSource from "../../examples/molecules/topic-notifications-button?source=file";

export default <template>
  <StyleguideExample
    @title="<TopicNotificationsButton> expanded"
    @code={{topicNotificationsButtonSource}}
  >
    <TopicNotificationsButtonExample
      @topic={{@dummy.topic}}
      @expanded={{true}}
    />
  </StyleguideExample>

  <StyleguideExample
    @title="<TopicNotificationsButton>"
    @code={{topicNotificationsButtonSource}}
  >
    <TopicNotificationsButtonExample
      @topic={{@dummy.topic}}
      @expanded={{false}}
    />
  </StyleguideExample>
</template>
