import { cached } from "@glimmer/tracking";

import GlimmerComponent from "discourse/components/glimmer";
import TagSectionLink from "discourse/lib/sidebar/tags-section/tag-section-link";

export default class SidebarTagsSection extends GlimmerComponent {
  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        sectionLink.refreshCounts();
      });
    });
  }

  willDestroy() {
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  @cached
  get sectionLinks() {
    return this.currentUser.trackedTags.map((trackedTag) => {
      return new TagSectionLink({
        tagName: trackedTag,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
