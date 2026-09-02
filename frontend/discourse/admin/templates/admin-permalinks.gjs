import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-permalinks admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.permalinks.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/20930"
      @titleLabel={{i18n "admin.config.permalinks.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.permalinks.title"}}
          @path="/admin/config/permalinks"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          class="admin-permalinks__header-add-permalink"
          @label="admin.permalink.add"
          @route="adminPermalinks.new"
          @title="admin.permalink.add"
        />
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-permalinks-tabs__settings"
          @label="admin.permalink.nav.settings"
          @route="adminPermalinks.settings"
        />
        <DNavItem
          class="admin-permalins-permalinks"
          @label="admin.permalink.nav.permalinks"
          @route="adminPermalinks.index"
        />
      </:tabs>
    </DPageHeader>
    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
