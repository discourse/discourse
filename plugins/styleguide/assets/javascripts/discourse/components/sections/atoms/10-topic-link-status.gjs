import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import NoStatusExample from "../../examples/atoms/topic-link-status/no-status";
import noStatusSource from "../../examples/atoms/topic-link-status/no-status?source=file";
import WithStatusExample from "../../examples/atoms/topic-link-status/with-status";
import withStatusSource from "../../examples/atoms/topic-link-status/with-status?source=file";

export default <template>
  <StyleguideExample @code={{noStatusSource}} @title="topic-link (no status)">
    <NoStatusExample @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: invisible)"
  >
    <WithStatusExample @topic={{@dummy.invisibleTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: closed)"
  >
    <WithStatusExample @topic={{@dummy.closedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: pinned)"
  >
    <WithStatusExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: unpinned)"
  >
    <WithStatusExample @topic={{@dummy.unpinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: archived)"
  >
    <WithStatusExample @topic={{@dummy.archivedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{withStatusSource}}
    @title="topic-link (status: warning)"
  >
    <WithStatusExample @topic={{@dummy.warningTopic}} />
  </StyleguideExample>
</template>
