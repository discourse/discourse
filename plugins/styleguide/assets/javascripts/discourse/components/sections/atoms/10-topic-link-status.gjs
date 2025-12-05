import Component from "@glimmer/component";
import TopicStatus from "discourse/components/topic-status";
import topicLink from "discourse/helpers/topic-link";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicStatuses extends Component {
  get noStatusCode() {
    return `
import topicLink from "discourse/helpers/topic-link";

<template>
  {{topicLink @dummy.topic}}
</template>
    `;
  }

  get invisibleCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.invisibleTopic}} />
  {{topicLink @dummy.invisibleTopic}}
</template>
    `;
  }

  get closedCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.closedTopic}} />
  {{topicLink @dummy.closedTopic}}
</template>
    `;
  }

  get pinnedCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.pinnedTopic}} />
  {{topicLink @dummy.pinnedTopic}}
</template>
    `;
  }

  get unpinnedCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.unpinnedTopic}} />
  {{topicLink @dummy.unpinnedTopic}}
</template>
    `;
  }

  get archivedCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.archivedTopic}} />
  {{topicLink @dummy.archivedTopic}}
</template>
    `;
  }

  get warningCode() {
    return `
import topicLink from "discourse/helpers/topic-link";
import TopicStatus from "discourse/components/topic-status";

<template>
  <TopicStatus @topic={{@dummy.warningTopic}} />
  {{topicLink @dummy.warningTopic}}
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="topic-link (no status)"
      @code={{this.noStatusCode}}
    >
      {{topicLink @dummy.topic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: invisible)"
      @code={{this.invisibleCode}}
    >
      <TopicStatus @topic={{@dummy.invisibleTopic}} />
      {{topicLink @dummy.invisibleTopic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: closed)"
      @code={{this.closedCode}}
    >
      <TopicStatus @topic={{@dummy.closedTopic}} />
      {{topicLink @dummy.closedTopic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: pinned)"
      @code={{this.pinnedCode}}
    >
      <TopicStatus @topic={{@dummy.pinnedTopic}} />
      {{topicLink @dummy.pinnedTopic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: unpinned)"
      @code={{this.unpinnedCode}}
    >
      <TopicStatus @topic={{@dummy.unpinnedTopic}} />
      {{topicLink @dummy.unpinnedTopic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: archived)"
      @code={{this.archivedCode}}
    >
      <TopicStatus @topic={{@dummy.archivedTopic}} />
      {{topicLink @dummy.archivedTopic}}
    </StyleguideExample>

    <StyleguideExample
      @title="topic-link (status: warning)"
      @code={{this.warningCode}}
    >
      <TopicStatus @topic={{@dummy.warningTopic}} />
      {{topicLink @dummy.warningTopic}}
    </StyleguideExample>
  </template>
}
