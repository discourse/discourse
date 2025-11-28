import WebhooksList from "discourse/admin/components/admin-config-areas/webhooks-list";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.webhooks.title"}}
    @descriptionLabel={{i18n "admin.config.webhooks.header_description"}}
    @hideTabs={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/api/web_hooks"
        @label={{i18n "admin.config.webhooks.title"}}
      />
    </:breadcrumbs>
    <:actions as |actions|>
      <actions.Primary
        @route="adminWebHooks.new"
        @label="admin.web_hooks.add"
      />
    </:actions>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <WebhooksList @webhooks={{@controller.model}} />
  </div>
</template>
