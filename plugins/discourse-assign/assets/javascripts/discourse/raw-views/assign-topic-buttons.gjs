import EmberObject from "@ember/object";
import { service } from "@ember/service";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import AssignedTopicListColumn from "../components/assigned-topic-list-column";

const ASSIGN_LIST_ROUTES = ["userActivity.assigned", "group.assigned.show"];

export default class extends EmberObject {
  @service router;

  get html() {
    if (ASSIGN_LIST_ROUTES.includes(this.router.currentRouteName)) {
      return rawRenderGlimmer(
        this,
        "td.assign-topic-buttons",
        <template><AssignedTopicListColumn @topic={{@data.topic}} /></template>,
        { topic: this.topic }
      );
    }
  }
}
