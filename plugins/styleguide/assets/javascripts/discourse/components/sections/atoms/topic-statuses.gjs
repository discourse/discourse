import TopicStatus from "discourse/components/topic-status";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicStatuses = <template>
  <StyleguideExample @title="invisible">
    <TopicStatus @topic={{@dummy.invisibleTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="closed">
    <TopicStatus @topic={{@dummy.closedTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="pinned">
    <TopicStatus @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="unpinned">
    <TopicStatus @topic={{@dummy.unpinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="archived">
    <TopicStatus @topic={{@dummy.archivedTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="warning">
    <TopicStatus @topic={{@dummy.warningTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="no status">
    <TopicStatus @topic={{@dummy.topic}} />
  </StyleguideExample>
</template>;

export default TopicStatuses;
