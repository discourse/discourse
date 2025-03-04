import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminBrandingLogoForm from "admin/components/admin-branding-logo-form";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";

export default RouteTemplate(
  <template>
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.logo.title"}}
      @descriptionLabel={{i18n "admin.config.logo.header_description"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/logo"
          @label={{i18n "admin.config.logo.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <AdminConfigAreaCard
      @heading="admin.config.branding.logo.title"
      @collapsable={{true}}
      class="admin-config-area-branding__logo"
    >
      <:content>
        <AdminBrandingLogoForm />
      </:content>
    </AdminConfigAreaCard>
  </template>
);
