import { concat } from "@ember/helper";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiFeatureSettingField from "discourse/plugins/discourse-ai/discourse/components/ai-feature-setting-field";

export default <template>
  <BackButton
    @route="adminPlugins.show.discourse-ai-features"
    @label="discourse_ai.features.back"
  />
  <div class="admin-config-area">
    <div class="admin-config-area__primary-content admin-ai-features-edit">
      <h2 class="admin-config-area__title">
        {{i18n (concat "discourse_ai.features." @model.module_name ".name")}}
      </h2>
      {{#if @model.feature_settings.length}}
        <AdminConfigAreaCard>
          <:content>
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
                          @type={{if
                            (eq setting.type "bool")
                            "checkbox"
                            (if
                              (eq setting.type "integer")
                              "input-number"
                              (if
                                (eq setting.type "enum")
                                "select"
                                (if (eq setting.type "list") "custom" "input")
                              )
                            )
                          }}
                          as |field|
                        >
                          <AiFeatureSettingField
                            @Control={{field.Control}}
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
          </:content>
        </AdminConfigAreaCard>

      {{/if}}
    </div>
  </div>
</template>
