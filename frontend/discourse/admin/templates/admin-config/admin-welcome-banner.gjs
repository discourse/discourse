import AdminWelcomeBannerForm from "discourse/admin/components/admin-welcome-banner-form";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-config-page">
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.welcome_banner.title"}}
      @descriptionLabel={{i18n
        "admin.config.welcome_banner.header_description"
      }}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/welcome-banner"
          @label={{i18n "admin.config.welcome_banner.title"}}
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
