import { i18n } from "discourse-i18n";
import SectionLink from "../section-link";

const SidebarCommonAllTagsSectionLink = <template>
  <SectionLink
    @linkName="all-tags"
    @content={{i18n "sidebar.all_tags"}}
    @route="tags"
    @prefixType="icon"
    @prefixValue="list"
  />
</template>;

export default SidebarCommonAllTagsSectionLink;
