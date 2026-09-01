import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isActiveLink } from "discourse/lib/sidebar/active-link";
import { i18n } from "discourse-i18n";
import SectionLink from "../section-link";

export default class SidebarCommonAllTagsSectionLink extends Component {
  @service router;

  get scrollIntoView() {
    return (
      this.args.scrollActiveLinkIntoView &&
      isActiveLink({ route: "tags" }, this.router)
    );
  }

  <template>
    <SectionLink
      @content={{i18n "sidebar.all_tags"}}
      @linkName="all-tags"
      @prefixType="icon"
      @prefixValue="list"
      @route="tags"
      @scrollIntoView={{this.scrollIntoView}}
    />
  </template>
}
