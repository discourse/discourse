import Component from "@glimmer/component";
import MoreTopics from "discourse/components/more-topics";
import RelatedMessages from "discourse/components/related-messages";
import SuggestedTopics from "discourse/components/suggested-topics";
import { withPluginApi } from "discourse/lib/plugin-api";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

let TAB_ADDED = false;

export default class MoreTopicsOrganism extends Component {
  constructor() {
    super(...arguments);

    if (!TAB_ADDED) {
      withPluginApi((api) => {
        api.registerMoreTopicsTab({
          id: "other-topics",
          name: "Other topics",
          component: SuggestedTopics,
          condition: () =>
            api.container.lookup("service:router").currentRouteName ===
            "styleguide.show",
        });
      });

      TAB_ADDED = true;
    }
  }

  get suggestedTopicsCode() {
    return `
import SuggestedTopics from "discourse/components/suggested-topics";

<template>
  <SuggestedTopics @topic={{@dummy.topic}} />
</template>
    `;
  }

  get relatedMessagesCode() {
    return `
import RelatedMessages from "discourse/components/related-messages";

<template>
  <RelatedMessages @topic={{@dummy.pmTopic}} />
</template>
    `;
  }

  get moreTopicsCode() {
    return `
import MoreTopics from "discourse/components/more-topics";

<template>
  <MoreTopics @topic={{@dummy.topic}} />
</template>
    `;
  }

  get moreTopicsWithPostersCode() {
    return `
import MoreTopics from "discourse/components/more-topics";

<template>
  <MoreTopics @topic={{@dummy.pmTopic}} />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<SuggestedTopics>"
      @code={{this.suggestedTopicsCode}}
    >
      <SuggestedTopics @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<RelatedMessages>"
      @code={{this.relatedMessagesCode}}
    >
      <RelatedMessages @topic={{@dummy.pmTopic}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<MoreTopics> - with tabs"
      @code={{this.moreTopicsCode}}
    >
      <MoreTopics @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<MoreTopics> - with tabs, and posters column"
      @code={{this.moreTopicsWithPostersCode}}
    >
      <MoreTopics @topic={{@dummy.pmTopic}} />
    </StyleguideExample>
  </template>
}
