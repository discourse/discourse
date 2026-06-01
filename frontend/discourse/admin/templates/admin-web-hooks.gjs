import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-webhooks admin-config-page">
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
      <PluginOutlet @name="admin-web-hooks">
        {{outlet}}
      </PluginOutlet>
    </div>
  </div>
</template>
