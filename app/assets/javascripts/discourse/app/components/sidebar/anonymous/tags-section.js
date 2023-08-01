import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";

export default class SidebarAnonymousTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service site;

  get displaySection() {
    return (
      this.site.anonymous_default_navigation_menu_tags?.length > 0 ||
      this.site.navigation_menu_site_top_tags?.length > 0
    );
  }

  @cached
  get sectionLinks() {
    return (
      this.site.anonymous_default_navigation_menu_tags ||
      this.site.navigation_menu_site_top_tags
    ).map((tag) => {
      return new TagSectionLink({
        tag,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
