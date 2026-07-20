import { array } from "@ember/helper";
import BrowserTrafficExplorer from "discourse/admin/components/browser-traffic-explorer";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.browser_traffic.title"}}
    @descriptionLabel={{i18n "admin.browser_traffic.description"}}
    @hideTabs={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/site-traffic"
        @label={{i18n "admin.browser_traffic.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    {{#each (array @model) key="@identity" as |model|}}
      <BrowserTrafficExplorer @model={{model}} />
    {{/each}}
  </div>
</template>
