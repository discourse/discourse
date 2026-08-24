import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import SectionLink from "../section-link";

export default class SidebarCommonAllCategoriesSectionLink extends Component {
  @service router;

  get scrollIntoView() {
    return (
      this.args.scrollActiveLinkIntoView &&
      this.router.isActive("discovery.categories")
    );
  }

  <template>
    <SectionLink
      @linkName="all-categories"
      @content={{i18n "sidebar.all_categories"}}
      @route="discovery.categories"
      @prefixType="icon"
      @prefixValue="sidebar.all_categories"
      @scrollIntoView={{this.scrollIntoView}}
    />
  </template>
}
