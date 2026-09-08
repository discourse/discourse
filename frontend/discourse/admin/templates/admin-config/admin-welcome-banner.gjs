import AdminWelcomeBannerForm from "discourse/admin/components/admin-welcome-banner-form";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n
        "admin.config.welcome_banner.header_description"
      }}
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.welcome_banner.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.welcome_banner.title"}}
          @path="/admin/config/welcome-banner"
        />
      </:breadcrumbs>
    </DPageHeader>
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <AdminWelcomeBannerForm />
      </div>
    </div>
  </div>
</template>
