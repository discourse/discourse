import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { dependentKeyCompat } from "@ember/object/compat";
import { readOnly } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SettingValidationMessage from "admin/components/setting-validation-message";
import Description from "admin/components/site-settings/description";
import SettingComponent from "admin/mixins/setting-component";
import SiteSetting from "admin/models/site-setting";

export default class SiteSettingComponent extends Component.extend(
  SettingComponent
) {
  @tracked setting = null;
  updateExistingUsers = null;

  @readOnly("setting.staffLogFilter") staffLogFilter;

  get resolvedComponent() {
    return getOwner(this).resolveRegistration(
      `component:${this.componentName}`
    );
  }

  @dependentKeyCompat
  get buffered() {
    return this.setting.buffered;
  }

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.setting.updateExistingUsers,
    });
  }

  <template>
    {{#if this.defaultIsAvailable}}
      <DButton
        class="btn-link"
        @action={{this.setDefaultValues}}
        @translatedLabel={{this.setting.setDefaultValuesLabel}}
      />
    {{/if}}
    <div class="setting-value form-kit__container">
      <label class="form-kit__container-title">
        {{this.settingName}}

        {{#if this.overridden}}
          {{#if this.setting.secret}}
            <DButton
              @action={{this.toggleSecret}}
              @icon="far-eye-slash"
              @ariaLabel="admin.settings.unmask"
              class="setting-toggle-secret"
            />
          {{/if}}
          <DButton
            class="btn-transparent undo setting-controls__undo"
            @action={{this.resetDefault}}
            @icon="arrow-rotate-left"
            @title="admin.settings.reset"
          />
        {{/if}}

        {{#if this.staffLogFilter}}
          <LinkTo
            @route="adminLogs.staffActionLogs"
            @query={{hash filters=this.staffLogFilter force_refresh=true}}
            title={{i18n "admin.settings.history"}}
          >
            <span class="history-icon">
              {{icon "calendar-days"}}
            </span>
          </LinkTo>
        {{/if}}
      </label>
      {{#if this.settingEditButton}}
        <DButton
          @action={{this.settingEditButton.action}}
          @icon={{this.settingEditButton.icon}}
          @label={{this.settingEditButton.label}}
          class="setting-value-edit-button"
        />

        <Description @description={{this.setting.description}} />
      {{else}}
        {{#if this.displayDescription}}
          <Description @description={{this.setting.description}} />
        {{/if}}
        <this.resolvedComponent
          @setting={{this.setting}}
          @value={{this.buffered.value}}
          @preview={{this.preview}}
          @isSecret={{this.isSecret}}
          @allowAny={{this.allowAny}}
          @changeValueCallback={{this.changeValueCallback}}
          @setValidationMessage={{this.setValidationMessage}}
          @class="form-kit__container-content --large"
        />
        {{#if this.setting.validationMessage}}
          <SettingValidationMessage
            @message={{this.setting.validationMessage}}
          />
        {{/if}}
      {{/if}}
    </div>

    {{#if this.dirty}}
      <div class="setting-controls">
        <DButton
          @action={{this.update}}
          @icon="check"
          @isLoading={{this.disableControls}}
          @ariaLabel="admin.settings.save"
          class="ok setting-controls__ok"
        />
        <DButton
          @action={{this.cancel}}
          @icon="xmark"
          @isLoading={{this.disableControls}}
          @ariaLabel="admin.settings.cancel"
          class="cancel setting-controls__cancel"
        />
      </div>
    {{/if}}
  </template>
}
