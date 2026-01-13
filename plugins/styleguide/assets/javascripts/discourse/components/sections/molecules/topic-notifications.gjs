import Component from "@glimmer/component";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicNotifications extends Component {
  expandedCode = `<TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{true}} />`;

  defaultCode = `<TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{false}} />`;

  <template>
    <StyleguideExample
      @title="<TopicNotificationsButton> expanded"
      @code={{this.expandedCode}}
    >
      <TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{true}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<TopicNotificationsButton>"
      @code={{this.defaultCode}}
    >
      <TopicNotificationsButton @topic={{@dummy.topic}} @expanded={{false}} />
    </StyleguideExample>
  </template>
}
