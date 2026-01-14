import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChangesBanner from "discourse/admin/components/changes-banner";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service siteSettingChangeTracker;

  @action
  async save() {
    await this.siteSettingChangeTracker.save();
  }

  @action
  discard() {
    this.siteSettingChangeTracker.discard();
  }

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

  <template>
    {{#if (gt this.dirtyCount 0)}}
      <ChangesBanner
        @bannerLabel={{this.bannerLabel}}
        @saveLabel={{this.saveLabel}}
        @discardLabel={{this.discardLabel}}
        @save={{this.save}}
        @discard={{this.discard}}
      />
    {{/if}}
  </template>
}
