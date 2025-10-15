import { get } from "@ember/helper";
import { eq } from "truth-helpers";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";

<template>
  <div class="ai-user-preferences">
    <legend class="control-label">{{i18n "discourse_ai.title"}}</legend>

    {{#each @controller.booleanSettings as |setting|}}
      {{#if setting.isIncluded}}
        <div class="control-group ai-setting">
          <PreferenceCheckbox
            @labelKey={{setting.label}}
            @checked={{get @controller.model.user_option setting.key}}
            data-setting-name={{setting.settingName}}
            class="pref-{{setting.settingName}}"
          />
        </div>
      {{/if}}
    {{/each}}

    {{#if (eq @controller.userSettingAttributes.length 0)}}
      {{i18n "discourse_ai.user_preferences.empty"}}
    {{/if}}

    {{#unless (eq @controller.userSettingAttributes.length 0)}}
      <SaveControls
        @id="user_ai_preference_save"
        @model={{@controller.model}}
        @action={{@controller.save}}
        @saved={{@controller.saved}}
      />
    {{/unless}}
  </div>
</template>
