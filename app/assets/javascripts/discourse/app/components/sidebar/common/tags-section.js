import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export const TOP_SITE_TAGS_TO_SHOW = 5;

export default class SidebarCommonTagsSection extends Component {
  @service site;

  topSiteTags = [];

  constructor() {
    super(...arguments);

    if (this.site.top_tags?.length > 0) {
      this.site.top_tags.splice(0, TOP_SITE_TAGS_TO_SHOW).forEach((tagName) => {
        this.topSiteTags.push(tagName);
      });
    }
  }
}
