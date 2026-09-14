import Component from "@glimmer/component";
import { service } from "@ember/service";
import { SYSTEM_FLAG_IDS } from "discourse/admin/lib/constants";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

class FlagsTemplate extends Component {
  @service site;
  @service siteSettings;

  get addFlagButtonDisabled() {
    return (
      this.site.flagTypes.filter(
        (flag) => !Object.values(SYSTEM_FLAG_IDS).includes(flag.id)
      ).length >= this.siteSettings.custom_flags_limit
    );
  }

  <template>
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.flags.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/moderation-flags/325589"
      @titleLabel={{i18n "admin.config.flags.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.flags.title"}}
          @path="/admin/config/flags"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          class="admin-flags__header-add-flag"
          @disabled={{this.addFlagButtonDisabled}}
          @label="admin.config_areas.flags.add"
          @route="adminConfig.flags.new"
          @title="admin.config_areas.flags.add"
        />
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-flags-tabs__settings"
          @label="settings"
          @route="adminConfig.flags.settings"
        />
        <DNavItem
          class="admin-flags-tabs__flags"
          @label="admin.config_areas.flags.flags_tab"
          @route="adminConfig.flags.index"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
}

export default FlagsTemplate;
