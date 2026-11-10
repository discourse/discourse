import AdminSearch from "discourse/admin/components/admin-search";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{@controller.description}}
    @shouldDisplay={{true}}
    @titleLabel={{i18n "admin.config.search_everything.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.search_everything.title"}}
        @path="/admin/search"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <div class="admin-config-area__full-width">
      <AdminSearch @initialFilter={{@controller.filter}} />
    </div>
  </div>
</template>
