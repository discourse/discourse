import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import NoStatusExample from "../../examples/atoms/topic-link-status/no-status";
import noStatusSource from "../../examples/atoms/topic-link-status/no-status?source=file";
import WithStatusExample from "../../examples/atoms/topic-link-status/with-status";
import withStatusSource from "../../examples/atoms/topic-link-status/with-status?source=file";

export default <template>
  <StyleguideExample @title="topic-link (no status)" @code={{noStatusSource}}>
    <NoStatusExample @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: invisible)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.invisibleTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: closed)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.closedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: pinned)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: unpinned)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.unpinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: archived)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.archivedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="topic-link (status: warning)"
    @code={{withStatusSource}}
  >
    <WithStatusExample @topic={{@dummy.warningTopic}} />
  </StyleguideExample>
</template>
