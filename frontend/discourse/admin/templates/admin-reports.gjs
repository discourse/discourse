import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.showHeader}}
    <DPageHeader
      @titleLabel={{i18n "admin.config.reports.title"}}
      @descriptionLabel={{i18n "admin.config.reports.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/-/240233"
      @hideTabs={{@controller.hideTabs}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/reports"
          @label={{i18n "admin.config.reports.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>
  {{/if}}

  <div class="admin-container admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
