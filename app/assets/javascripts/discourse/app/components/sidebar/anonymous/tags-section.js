import { cached } from "@glimmer/tracking";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";

export default class SidebarAnonymousTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service site;

  get displaySection() {
    return (
      this.site.anonymous_default_sidebar_tags?.length > 0 ||
      this.site.top_tags?.length > 0
    );
  }

  @cached
  get sectionLinks() {
    let tags;

    if (this.site.anonymous_default_sidebar_tags) {
      tags = this.site.anonymous_default_sidebar_tags;
    } else {
      tags = this.site.top_tags.slice(0, 5);
    }
    return tags.map((tagName) => {
      return new TagSectionLink({
        tagName,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
