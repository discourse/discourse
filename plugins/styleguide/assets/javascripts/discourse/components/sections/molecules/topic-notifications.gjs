import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicNotificationsButtonExample from "../../examples/molecules/topic-notifications-button";
import topicNotificationsButtonSource from "../../examples/molecules/topic-notifications-button?source=file";

export default <template>
  <StyleguideExample
    @code={{topicNotificationsButtonSource}}
    @title="<TopicNotificationsButton> expanded"
  >
    <TopicNotificationsButtonExample
      @expanded={{true}}
      @topic={{@dummy.topic}}
    />
  </StyleguideExample>

  <StyleguideExample
    @code={{topicNotificationsButtonSource}}
    @title="<TopicNotificationsButton>"
  >
    <TopicNotificationsButtonExample
      @expanded={{false}}
      @topic={{@dummy.topic}}
    />
  </StyleguideExample>
</template>
