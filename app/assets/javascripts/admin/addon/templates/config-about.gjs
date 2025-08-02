import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import basePath from "discourse/helpers/base-path";
import { i18n } from "discourse-i18n";
import About from "admin/components/admin-config-areas/about";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.about.title"}}
      @descriptionLabel={{i18n
        "admin.config.about.header_description"
        (hash basePath=(basePath))
      }}
      @hideTabs={{true}}
      @learnMoreUrl="https://meta.discourse.org/t/understanding-and-customizing-the-about-page/332161"
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/about"
          @label={{i18n "admin.config.about.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <About @data={{@controller.model.site_settings}} />
    </div>
  </template>
);
