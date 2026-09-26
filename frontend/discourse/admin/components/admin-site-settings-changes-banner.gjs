import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import ChangesBanner from "discourse/admin/components/changes-banner";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import SiteSettingChangeTrackerService from "discourse/admin/services/site-setting-change-tracker";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service(() => SiteSettingChangeTrackerService) siteSettingChangeTracker;

  get dirtyCount() {
    return this.siteSettingChangeTracker.count;
  }

  get bannerLabel() {
    return i18n("admin.site_settings.dirty_banner", {
      count: this.dirtyCount,
    });
  }

  get saveLabel() {
    return i18n("admin.site_settings.save", {
      count: this.dirtyCount,
    });
  }

  get discardLabel() {
    return i18n("admin.site_settings.discard", {
      count: this.dirtyCount,
    });
  }

  @action
  async save() {
    await this.siteSettingChangeTracker.save();
  }

  @action
  discard() {
    this.siteSettingChangeTracker.discard();
  }

  <template>
    {{#if (gt this.dirtyCount 0)}}
      <ChangesBanner
        @bannerLabel={{this.bannerLabel}}
        @discard={{this.discard}}
        @discardLabel={{this.discardLabel}}
        @save={{this.save}}
        @saveLabel={{this.saveLabel}}
      />
    {{/if}}
  </template>
}
