import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import { i18n } from "discourse-i18n";

export default <template>
  <BackButton
    @label="discourse_ai.features.back"
    @route="adminPlugins.show.discourse-ai-features"
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
              class="ai-feature-editor"
              @data={{@model.formData}}
              @onRegisterApi={{@controller.onRegisterFormApi}}
              @onSubmit={{@controller.save}}
              as |form data|
            >
              {{#if @model.settingGroups.length}}
                {{#each @model.settingGroups as |group|}}
                  <form.Section @title={{i18n group.titleKey}}>
                    {{#if group.descriptionKey}}
                      <p class="ai-feature-editor__section-description">
                        {{i18n group.descriptionKey}}
                      </p>
                    {{/if}}
                    {{#each group.settings as |settingName|}}
                      {{#let
                        (@controller.findSetting settingName)
                        as |setting|
                      }}
                        {{#if (@controller.isSettingVisible setting data)}}
                          <SettingDefinitionField
                            @definition={{@controller.settingDefinition
                              setting
                            }}
                            @disabled={{setting.disabled}}
                            @form={{form}}
                          />
                        {{/if}}
                      {{/let}}
                    {{/each}}
                  </form.Section>
                  {{#if (eq @model.module_name "sentiment")}}
                    {{#if
                      (eq
                        group.key
                        (@controller.sentimentBackendGroup
                          data "decision_model"
                        )
                      )
                    }}
                      <p class="ai-feature-editor__model-change-warning">
                        {{i18n
                          "discourse_ai.features.sentiment.model_change_warning"
                        }}
                      </p>
                      <LinkTo
                        class="ai-feature-editor__decision-models-link"
                        @query={{hash type="decision"}}
                        @route="adminPlugins.show.discourse-ai-models.index"
                      >
                        {{i18n
                          "discourse_ai.features.sentiment.manage_decision_models"
                        }}
                      </LinkTo>
                    {{/if}}
                    {{#if
                      (eq
                        group.key
                        (@controller.sentimentBackendGroup
                          data "classification_model"
                        )
                      )
                    }}
                      <p class="ai-feature-editor__dedicated-description">
                        {{i18n
                          "discourse_ai.features.sentiment.dedicated_description"
                        }}
                        <LinkTo
                          class="ai-feature-editor__dedicated-link"
                          @model="all_results"
                          @query={{hash filter="ai_sentiment_model_configs"}}
                          @route="adminSiteSettingsCategory"
                        >
                          {{i18n
                            "discourse_ai.features.sentiment.configure_dedicated"
                          }}
                        </LinkTo>
                      </p>
                    {{/if}}
                  {{/if}}
                {{/each}}
              {{else}}
                {{#each @model.feature_settings as |setting|}}
                  {{#if (@controller.isSettingVisible setting data)}}
                    <SettingDefinitionField
                      @definition={{@controller.settingDefinition setting}}
                      @disabled={{setting.disabled}}
                      @form={{form}}
                    />
                  {{/if}}
                {{/each}}
              {{/if}}
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
