import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminLogoForm from "admin/components/admin-logo-form";

export default RouteTemplate(
  <template>
    <div class="admin-config-page">
      <DPageHeader
        @hideTabs={{true}}
        @titleLabel={{i18n "admin.config.logo.title"}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/config/logo"
            @label={{i18n "admin.config.logo.title"}}
          />
        </:breadcrumbs>
      </DPageHeader>
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          <AdminConfigAreaCard
            @heading="admin.config.logo.title"
            @collapsable={{true}}
            class="admin-config-area__logo"
          >
            <:content>
              <AdminLogoForm />
            </:content>
          </AdminConfigAreaCard>
        </div>
      </div>
    </div>
  </template>
);
