import { concat } from "@ember/helper";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import { i18n } from "discourse-i18n";

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
              {{#if @model.settingGroups.length}}
                {{#each @model.settingGroups as |group|}}
                  <form.Section @title={{i18n group.titleKey}}>
                    {{#each group.settings as |settingName|}}
                      {{#let
                        (@controller.findSetting settingName)
                        as |setting|
                      }}
                        {{#if setting}}
                          <SettingDefinitionField
                            @definition={{setting.definition}}
                            @form={{form}}
                          />
                        {{/if}}
                      {{/let}}
                    {{/each}}
                  </form.Section>
                {{/each}}
              {{else}}
                {{#each @model.feature_settings as |setting|}}
                  <SettingDefinitionField
                    @definition={{setting.definition}}
                    @form={{form}}
                  />
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
