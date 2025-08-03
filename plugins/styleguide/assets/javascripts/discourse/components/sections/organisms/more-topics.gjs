import Component from "@glimmer/component";
import MoreTopics from "discourse/components/more-topics";
import RelatedMessages from "discourse/components/related-messages";
import SuggestedTopics from "discourse/components/suggested-topics";
import { cloneJSON } from "discourse/lib/object";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class MoreTopicsOrganism extends Component {
  <template>
    <StyleguideExample @title="<SuggestedTopics>">
      <SuggestedTopics @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample @title="<RelatedMessages>">
      <RelatedMessages @topic={{@dummy.pmTopic}} />
    </StyleguideExample>

    <StyleguideExample @title="<SuggestedTopics> - with tabs">
      <MoreTopics @topic={{@dummy.pmTopic}} />
    </StyleguideExample>
  </template>
}
