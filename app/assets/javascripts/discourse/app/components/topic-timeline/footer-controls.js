import GlimmerComponent from "discourse/components/glimmer";

export default class TopicTimelineFooterControls extends GlimmerComponent {
  get canCreatePost() {
    return this.args.topic.get("details.can_create_post");
  }
}
