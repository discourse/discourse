import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config_sections.account.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config_sections.account.title"}}
        @path="/admin/section/account"
      />
    </:breadcrumbs>
  </DPageHeader>

  <AdminSectionLandingWrapper>
    <AdminSectionLandingItem
      @descriptionLabel="admin.config.backups.header_description"
      @icon="box-archive"
      @titleLabel="admin.config.backups.title"
      @titleRoute="admin.backups"
    />
    <AdminSectionLandingItem
      @descriptionLabel="admin.config.whats_new.header_description"
      @icon="gift"
      @titleLabel="admin.config.whats_new.title"
      @titleRoute="admin.whatsNew"
    />
  </AdminSectionLandingWrapper>
</template>
