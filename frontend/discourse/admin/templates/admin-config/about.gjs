import { hash } from "@ember/helper";
import About from "discourse/admin/components/admin-config-areas/about";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.about.title"}}
    @descriptionLabel={{i18n
      "admin.config.about.header_description"
      (hash basePath=(dBasePath))
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
