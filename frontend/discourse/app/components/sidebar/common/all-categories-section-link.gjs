import { i18n } from "discourse-i18n";
import SectionLink from "../section-link";

const SidebarCommonAllCategoriesSectionLink = <template>
  <SectionLink
    @linkName="all-categories"
    @content={{i18n "sidebar.all_categories"}}
    @route="discovery.categories"
    @prefixType="icon"
    @prefixValue="sidebar.all_categories"
  />
</template>;

export default SidebarCommonAllCategoriesSectionLink;
