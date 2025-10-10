import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @label="admin.customize.email_style.html"
          @route="adminCustomizeEmailStyle.edit"
          @routeParam="html"
        />
        <NavItem
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
);
