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

  <template>
    <StyleguideExample @title="<SuggestedTopics>">
      <SuggestedTopics @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample @title="<RelatedMessages>">
      <RelatedMessages @topic={{@dummy.pmTopic}} />
    </StyleguideExample>

    <StyleguideExample @title="<MoreTopics> - with tabs">
      <MoreTopics @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample @title="<MoreTopics> - with tabs, and posters column">
      <MoreTopics @topic={{@dummy.pmTopic}} />
    </StyleguideExample>
  </template>
}
