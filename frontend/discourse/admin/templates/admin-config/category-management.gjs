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
          @routeParam="all"
          @label="admin.config.category_management.types.all.title"
        />
        {{#each this.site.category_types as |categoryType|}}
          <DNavItem
            @route="adminConfig.categoryManagement.type"
            @routeParam={{categoryType.id}}
            @i18nLabel={{categoryType.name}}
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
