import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

import SidebarCommonTagsSection from "discourse/components/sidebar/common/tags-section";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";

export default class SidebarAnonymousTagsSection extends SidebarCommonTagsSection {
  @service router;
  @service topicTrackingState;
  @service site;

  get displaySection() {
    return (
      this.site.anonymous_default_navigation_menu_tags?.length > 0 ||
      this.topSiteTags?.length > 0
    );
  }

  @cached
  get sectionLinks() {
    return (
      this.site.anonymous_default_navigation_menu_tags || this.topSiteTags
    ).map((tagName) => {
      return new TagSectionLink({
        tagName,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
