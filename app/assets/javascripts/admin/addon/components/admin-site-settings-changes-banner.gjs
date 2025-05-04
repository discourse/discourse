import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsChangesBanner extends Component {
  @service siteSettingChangeTracker;

  @tracked isSaving = false;
  _resizer = null;

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

  @action
  setupResizeObserver(element) {
    const container = document.getElementById("main-container");
    this._resizer = () => this.positionBanner(container, element);

    this._resizer();

    this._resizeObserver = window.addEventListener("resize", this._resizer);
  }

  @action
  teardownResizeObserver() {
    window.removeEventListener("resize", this._resizer);
  }

  positionBanner(container, element) {
    if (container) {
      const { width } = container.getBoundingClientRect();

      element.style.width = `${width}px`;
    }
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
    {{#if this.showBanner}}
      <div
        class="admin-site-settings__changes-banner"
        {{didInsert this.setupResizeObserver}}
        {{willDestroy this.teardownResizeObserver}}
      >
        <span>{{htmlSafe this.bannerLabel}}</span>
        <div class="controls">
          <DButton
            @action={{this.discard}}
            @disabled={{this.isSaving}}
            class="btn-secondary btn-small"
          >
            {{this.discardLabel}}
          </DButton>
          <DButton
            @action={{this.save}}
            @isLoading={{this.isSaving}}
            class="btn-primary btn-small"
          >
            {{this.saveLabel}}
          </DButton>
        </div>
      </div>
    {{/if}}
  </template>
}
