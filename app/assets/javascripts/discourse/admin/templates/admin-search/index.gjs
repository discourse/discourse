import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminSearch from "admin/components/admin-search";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.search_everything.title"}}
      @descriptionLabel={{i18n
        "admin.config.search_everything.header_description"
        shortcutHTML=@controller.shortcutHTML
      }}
      @shouldDisplay={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/search"
          @label={{i18n "admin.config.search_everything.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <div class="admin-config-area__full-width">
        <AdminSearch @initialFilter={{@controller.filter}} />
      </div>
    </div>
  </template>
);
