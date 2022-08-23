import { cached } from "@glimmer/tracking";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import TagSectionLink from "discourse/lib/sidebar/tags-section/tag-section-link";

export default class SidebarAnonymousTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service site;

  @cached
  get sectionLinks() {
    let tags = [];

    if (this.site.anonymous_default_sidebar_tags) {
      tags = this.site.anonymous_default_sidebar_tags;
    } else {
      tags = this.site.top_tags.slice(0, 5);
    }
    return tags.map((tag) => {
      return new TagSectionLink({
        tag: { name: tag },
        topicTrackingState: this.topicTrackingState,
      });
    });
  }

  get moreLink() {
    return {
      name: "more-tags",
      text: I18n.t("sidebar.more"),
      route: "tags",
    };
  }
}
