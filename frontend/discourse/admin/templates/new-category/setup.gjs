import CategoryTypeCards from "discourse/components/category-type-cards";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="edit-category admin-new-category-setup">
    <DPageHeader @titleLabel={{i18n "category.choose_type.title"}} />
    <CategoryTypeCards @types={{@model.types}} @counts={{@model.counts}} />
  </div>
</template>
