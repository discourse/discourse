import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiFeatureSettingField from "discourse/plugins/discourse-ai/discourse/components/ai-feature-setting-field";

export default <template>
  <BackButton @route="adminPlugins.show.discourse-ai-features" />

  {{#if @model.feature_settings.length}}
    <Form
      @data={{@model.formData}}
      @onSubmit={{@controller.save}}
      @onRegisterApi={{@controller.onRegisterFormApi}}
      class="ai-feature-editor"
      as |form|
    >
      {{#each @model.settingGroups as |group|}}
        <form.Section @title={{i18n group.titleKey}}>
          {{#each group.settings as |settingName|}}
            {{#let (@controller.findSetting settingName) as |setting|}}
              {{#if setting}}
                <form.Field
                  @name={{setting.setting}}
                  @title={{setting.humanized_name}}
                  @description={{if
                    (eq setting.type "bool")
                    null
                    setting.description
                  }}
                  @format="large"
                  @validation={{@controller.getValidationFor setting}}
                  as |field|
                >
                  <AiFeatureSettingField
                    @setting={{setting}}
                    @field={{field}}
                  />
                </form.Field>
              {{/if}}
            {{/let}}
          {{/each}}
        </form.Section>
      {{/each}}

      <form.Actions>
        <form.Submit />
      </form.Actions>
    </Form>
  {{/if}}
</template>
