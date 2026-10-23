import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-webhooks admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.webhooks.header_description"}}
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.webhooks.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.webhooks.title"}}
          @path="/admin/api/web_hooks"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          @label="admin.web_hooks.add"
          @route="adminWebHooks.new"
        />
      </:actions>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <PluginOutlet @name="admin-web-hooks">
        {{outlet}}
      </PluginOutlet>
    </div>
  </div>
</template>
