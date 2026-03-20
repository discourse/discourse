import AdminFontsForm from "discourse/admin/components/admin-fonts-form";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
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
