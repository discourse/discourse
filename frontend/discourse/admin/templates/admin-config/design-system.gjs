import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.design_system.title"}}
    @descriptionLabel={{i18n "admin.config.design_system.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/design-system"
        @label={{i18n "admin.config.design_system.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminConfig.designSystem.colors"
        @label="admin.config.design_system.sub_pages.colors.title"
      />
      <DNavItem
        @route="adminConfig.designSystem.fonts"
        @label="admin.config.design_system.sub_pages.fonts.title"
      />
      <DNavItem
        @route="adminConfig.designSystem.layout"
        @label="admin.config.design_system.sub_pages.layout.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
