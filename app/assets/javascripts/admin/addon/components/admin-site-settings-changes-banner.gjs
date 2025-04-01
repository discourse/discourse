import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service siteSettingChangeTracker;

  @tracked isSaving = false;

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.siteSettingChangeTracker.save();
    } finally {
      this.isSaving = false;
    }
  }

  @action
  discard() {
    this.siteSettingChangeTracker.discard();
  }

  get dirtyCount() {
    return this.siteSettingChangeTracker.count;
  }

  get showBanner() {
    return this.dirtyCount > 0;
  }

  get bannerLabel() {
    return i18n("admin.site_settings.dirty_banner", {
      count: this.dirtyCount,
    });
  }

  <template>
    {{#if this.showBanner}}
      <div class="admin-site-settings__changes-banner">
        <span>{{htmlSafe this.bannerLabel}}</span>
        <div class="controls">
          <DButton
            @label="admin.site_settings.discard"
            @action={{this.discard}}
            @disabled={{this.isSaving}}
            class="btn-secondary btn-small"
          />
          <DButton
            @label="admin.site_settings.save"
            @action={{this.save}}
            @isLoading={{this.isSaving}}
            class="btn-primary btn-small"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
