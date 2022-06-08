import GlimmerComponent from "discourse/components/glimmer";
import CategorySectionLink from "discourse/lib/sidebar/categories-section/category-section-link";

export default class SidebarCategoriesSection extends GlimmerComponent {
  get sectionLinks() {
    return this.site.trackedCategoriesList.map((trackedCategory) => {
      return new CategorySectionLink({ category: trackedCategory });
    });
  }
}
