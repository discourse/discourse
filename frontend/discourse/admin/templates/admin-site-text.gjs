import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.site_texts.header_description"}}
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.site_texts.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.site_texts.title"}}
        @path="/admin/customize/site_texts"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="row site-texts">
    {{outlet}}
  </div>
</template>
