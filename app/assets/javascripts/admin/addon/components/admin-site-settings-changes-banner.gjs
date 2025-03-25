import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service siteSettingChangeTracker;

  @action discard() {
    this.siteSettingChangeTracker.discard();
  }

  get dirtyCount() {
    return this.siteSettingChangeTracker.count;
  }

  get display() {
    return this.dirtyCount > 0;
  }

  <template>
    {{#if this.dirtyCount}}
      <div class="admin-site-settings__changes-banner">
        <span>You have <em>{{this.dirtyCount}}</em> unsaved changes</span>
        <div class="controls">
          <DButton
            @label="admin.site_settings.discard"
            @action={{this.discard}}
            class="btn-secondary btn-small"
          />
          <DButton
            @label="admin.site_settings.save"
            class="btn-primary btn-small"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
