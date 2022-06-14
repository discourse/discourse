import { cached } from "@glimmer/tracking";

import GlimmerComponent from "discourse/components/glimmer";
import CategorySectionLink from "discourse/lib/sidebar/categories-section/category-section-link";

export default class SidebarCategoriesSection extends GlimmerComponent {
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
    return this.site.trackedCategoriesList.map((trackedCategory) => {
      return new CategorySectionLink({
        category: trackedCategory,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
