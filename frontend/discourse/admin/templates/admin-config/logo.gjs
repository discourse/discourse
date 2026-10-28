import AdminLogoForm from "discourse/admin/components/admin-logo-form";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-config-page">
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.logo.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.logo.title"}}
          @path="/admin/config/logo"
        />
      </:breadcrumbs>
    </DPageHeader>
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <AdminLogoForm />
      </div>
    </div>
  </div>
</template>
