import { concat } from "@ember/helper";
import WebhooksForm from "discourse/admin/components/admin-config-areas/webhooks-form";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader @titleLabel={{i18n "admin.web_hooks.edit"}} @hideTabs={{true}}>
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/api/web_hooks"
        @label={{i18n "admin.config.webhooks.title"}}
      />
      <DBreadcrumbsItem
        @path={{concat "/admin/api/web_hooks/" @model.id "/edit"}}
        @label={{i18n "admin.web_hooks.edit"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <WebhooksForm @webhook={{@model}} />
  </div>
</template>
