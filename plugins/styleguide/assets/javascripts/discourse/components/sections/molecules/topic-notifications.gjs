import TopicNotificationsButton from "select-kit/components/topic-notifications-button";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicNotifications = <template>
  <StyleguideExample @title="<TopicNotificationsButton> expanded">
    <TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{true}} />
  </StyleguideExample>

  <StyleguideExample @title="<TopicNotificationsButton>">
    <TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{false}} />
  </StyleguideExample>
</template>;

export default TopicNotifications;
