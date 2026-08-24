import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import SectionLink from "../section-link";

export default class SidebarCommonAllTagsSectionLink extends Component {
  @service router;

  get scrollIntoView() {
    return this.args.scrollActiveLinkIntoView && this.router.isActive("tags");
  }

  <template>
    <SectionLink
      @linkName="all-tags"
      @content={{i18n "sidebar.all_tags"}}
      @route="tags"
      @prefixType="icon"
      @prefixValue="list"
      @scrollIntoView={{this.scrollIntoView}}
    />
  </template>
}
