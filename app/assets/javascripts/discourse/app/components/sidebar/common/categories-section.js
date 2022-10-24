import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";

export default class SidebarCommonCategoriesSection extends Component {
  @service topicTrackingState;
  @service siteSettings;

  // Override in child
  get categories() {}

  @cached
  get sectionLinks() {
    return this.categories
      .sort((a, b) => a.name.localeCompare(b.name))
      .reduce((links, category) => {
        links.push(
          new CategorySectionLink({
            category,
            topicTrackingState: this.topicTrackingState,
            currentUser: this.currentUser,
          })
        );

        return links;
      }, []);
  }
}
