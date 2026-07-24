import { not } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

const AdminEmojisTemplate = <template>
  <div class="admin-emoji admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.config.emoji.title"}}
      @descriptionLabel={{i18n "admin.config.emoji.header_description"}}
      @hideTabs={{@controller.hideTabs}}
      @shouldDisplay={{not @controller.hideTabs}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/emoji"
          @label={{i18n "admin.config.emoji.title"}}
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary @route="adminEmojis.new" @label="admin.emoji.add" />
        <actions.Default
          @route="adminEmojis.import"
          @label="admin.emoji.import"
          class="admin-emoji__import"
        />
      </:actions>
      <:tabs>
        <DNavItem
          @route="adminEmojis.settings"
          @label="settings"
          class="admin-emoji-tabs__settings"
        />
        <DNavItem
          @route="adminEmojis.index"
          @label="admin.emoji.title"
          class="admin-emoji-tabs__emoji"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>;

export default AdminEmojisTemplate;
