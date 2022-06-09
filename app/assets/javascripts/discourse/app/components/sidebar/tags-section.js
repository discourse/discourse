import { cached } from "@glimmer/tracking";

import GlimmerComponent from "discourse/components/glimmer";
import TagSectionLink from "discourse/lib/sidebar/tags-section/tag-section-link";

export default class SidebarTagsSection extends GlimmerComponent {
  @cached
  get sectionLinks() {
    return this.currentUser.trackedTags.map((trackedTag) => {
      return new TagSectionLink({ tag: trackedTag });
    });
  }
}
