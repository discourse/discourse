import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n
      "admin.config.email_appearance.header_description"
    }}
    @shouldDisplay={{true}}
    @titleLabel={{i18n "admin.config.email_appearance.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.customize.email_style.heading"}}
        @path="/admin/customize/email_style"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @label="admin.customize.email_style.html"
        @route="adminCustomizeEmailStyle.edit"
        @routeParam="html"
      />
      <DNavItem
        @label="admin.customize.email_style.css"
        @route="adminCustomizeEmailStyle.edit"
        @routeParam="css"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
