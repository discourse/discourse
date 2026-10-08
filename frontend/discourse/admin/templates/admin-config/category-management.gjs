import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default class AdminConfigCategoryManagement extends Component {
  @service site;

  <template>
    <DPageHeader
      @descriptionLabel={{i18n
        "admin.config.category_management.header_description"
      }}
      @titleLabel={{i18n "admin.config.category_management.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.category_management.title"}}
          @path="/admin/config/category-management"
        />
      </:breadcrumbs>

      <:tabs>
        <DNavItem
          @label="admin.config.category_management.tabs.settings"
          @route="adminConfig.categoryManagement.settings"
        />
        <DNavItem
          @label="admin.config.category_management.types.all.title"
          @route="adminConfig.categoryManagement.type"
          @routeParam="all"
        />
        {{#each this.site.category_types as |categoryType|}}
          <DNavItem
            @i18nLabel={{categoryType.name}}
            @route="adminConfig.categoryManagement.type"
            @routeParam={{categoryType.id}}
          />
        {{/each}}
      </:tabs>

      <:actions as |actions|>
        <actions.Primary
          @label="admin.config.category_management.create_category"
          @route="newCategory.setup"
        />
      </:actions>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
}
