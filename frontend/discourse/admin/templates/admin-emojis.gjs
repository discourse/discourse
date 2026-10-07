import { not } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

const AdminEmojisTemplate = <template>
  <div class="admin-emoji admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.emoji.header_description"}}
      @hideTabs={{@controller.hideTabs}}
      @shouldDisplay={{not @controller.hideTabs}}
      @titleLabel={{i18n "admin.config.emoji.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.emoji.title"}}
          @path="/admin/config/emoji"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary @label="admin.emoji.add" @route="adminEmojis.new" />
        <actions.Default
          class="admin-emoji__import"
          @label="admin.emoji.import"
          @route="adminEmojis.import"
        />
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-emoji-tabs__settings"
          @label="settings"
          @route="adminEmojis.settings"
        />
        <DNavItem
          class="admin-emoji-tabs__emoji"
          @label="admin.emoji.title"
          @route="adminEmojis.index"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>;

export default AdminEmojisTemplate;
