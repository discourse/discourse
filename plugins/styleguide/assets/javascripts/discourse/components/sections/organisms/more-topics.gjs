import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import BasicTopicList from "discourse/components/basic-topic-list";
import MoreTopics from "discourse/components/more-topics";
import { withPluginApi } from "discourse/lib/plugin-api";
import ComboBox from "discourse/select-kit/components/combo-box";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

let TAB_ADDED = false;

const VARIANTS = [
  { id: "topic", name: "Topic" },
  { id: "pmTopic", name: "Private message" },
];

class OtherTopics extends Component {
  get topics() {
    return this.args.topic?.suggestedTopics?.slice().reverse();
  }

  <template>
    <div class="more-topics__list">
      <h3 class="more-topics__list-title">Other topics</h3>
      <div class="topics">
        <BasicTopicList @topics={{this.topics}} @listContext="other" />
      </div>
    </div>
  </template>
}

export default class MoreTopicsOrganism extends Component {
  @tracked variant = "topic";

  constructor() {
    super(...arguments);

    if (!TAB_ADDED) {
      withPluginApi((api) => {
        api.registerMoreTopicsTab({
          id: "other-topics",
          name: "Other topics",
          component: OtherTopics,
          condition: () =>
            api.container.lookup("service:router").currentRouteName ===
            "styleguide.show",
        });
      });

      TAB_ADDED = true;
    }
  }

  get currentTopic() {
    return this.args.dummy[this.variant];
  }

  @action
  selectVariant(value) {
    this.variant = value;
  }

  <template>
    <StyleguideExample @title="<MoreTopics>">
      <StyleguideComponent>
        <MoreTopics @topic={{this.currentTopic}} />
      </StyleguideComponent>

      <Controls>
        {{! template-lint-disable no-potential-path-strings}}
        <Row @name="@topic type">
          <ComboBox
            @value={{this.variant}}
            @content={{VARIANTS}}
            @onChange={{this.selectVariant}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
