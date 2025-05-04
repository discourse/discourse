import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.site_texts.title"}}
      @descriptionLabel={{i18n "admin.config.site_texts.header_description"}}
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/customize/site_texts"
          @label={{i18n "admin.config.site_texts.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="row site-texts">
      {{outlet}}
    </div>
  </template>
);
