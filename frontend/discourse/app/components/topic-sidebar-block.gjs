import Component from "@glimmer/component";
// import { service } from "@ember/service";
import { block } from "discourse/blocks";

@block("topic-sidebar-block", {
  description: "A block that displays a sidebar in the topic sidebar",
})
export default class TopicSidebarBlock extends Component {
  //   @service topicSidebar;

  constructor() {
    super(...arguments);
  }

  <template>
    <div class="topic-sidebar-block">
    </div>
  </template>
}
