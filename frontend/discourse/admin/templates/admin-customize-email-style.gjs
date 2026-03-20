import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.email_appearance.title"}}
    @descriptionLabel={{i18n
      "admin.config.email_appearance.header_description"
    }}
    @shouldDisplay={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/customize/email_style"
        @label={{i18n "admin.customize.email_style.heading"}}
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
