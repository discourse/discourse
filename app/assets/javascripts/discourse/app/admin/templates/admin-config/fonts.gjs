import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminFontsForm from "admin/components/admin-fonts-form";

export default RouteTemplate(
  <template>
    <div class="admin-config-page">
      <DPageHeader
        @hideTabs={{true}}
        @titleLabel={{i18n "admin.config.fonts.title"}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/config/fonts"
            @label={{i18n "admin.config.fonts.title"}}
          />
        </:breadcrumbs>
      </DPageHeader>
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          <AdminFontsForm />
        </div>
      </div>
    </div>
  </template>
);
