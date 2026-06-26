import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.category_management.title"}}
    @descriptionLabel={{i18n
      "admin.config.category_management.header_description"
    }}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/category-management"
        @label={{i18n "admin.config.category_management.title"}}
      />
    </:breadcrumbs>

    <:tabs>
      <DNavItem
        @route="adminConfig.categoryManagement.settings"
        @label="admin.config.category_management.tabs.settings"
      />
      <DNavItem
        @route="adminConfig.categoryManagement.type"
        @routeParam="discussion"
        @label="admin.config.category_management.types.discussion.title"
      />
      <DNavItem
        @route="adminConfig.categoryManagement.type"
        @routeParam="events"
        @label="admin.config.category_management.types.events.title"
      />
      <DNavItem
        @route="adminConfig.categoryManagement.type"
        @routeParam="support"
        @label="admin.config.category_management.types.support.title"
      />
      <DNavItem
        @route="adminConfig.categoryManagement.type"
        @routeParam="ideas"
        @label="admin.config.category_management.types.ideas.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
