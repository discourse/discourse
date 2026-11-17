import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DFloatingControlBar from "discourse/ui-kit/d-floating-control-bar";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service siteSettingChangeTracker;

  get dirtyCount() {
    return this.siteSettingChangeTracker.count;
  }

  get bannerLabel() {
    return trustHTML(
      i18n("admin.site_settings.dirty_banner", {
        count: this.dirtyCount,
      })
    );
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
      <DFloatingControlBar
        @discardLabel={{this.discardLabel}}
        @label={{this.bannerLabel}}
        @onDiscard={{this.discard}}
        @onSave={{this.save}}
        @saveLabel={{this.saveLabel}}
      />
    {{/if}}
  </template>
}
