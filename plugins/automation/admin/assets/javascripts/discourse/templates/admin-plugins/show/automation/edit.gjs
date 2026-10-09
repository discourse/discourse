import { fn, hash } from "@ember/helper";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import { and, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";
import AutomationEnabledToggle from "discourse/plugins/automation/admin/components/automation-enabled-toggle";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import FormError from "discourse/plugins/automation/admin/components/form-error";

export default <template>
  <div class="admin-detail discourse-automation-edit discourse-automation-form">
    <BackButton
      class="discourse-automation-back"
      @label="discourse_automation.back"
      @route="adminPlugins.show.automation.index"
    />

    {{#if @controller.automationForm.trigger}}
      <AdminConfigAreaCard class="automation-enabled-card">
        <:content>
          <div class="control-group automation-enabled">
            <label>{{i18n
                "discourse_automation.models.automation.enabled.label"
              }}</label>

            <span class="enabled-toggle-with-tooltip">
              <AutomationEnabledToggle
                @automation={{@controller.model.automation}}
                @canBeEnabled={{not @controller.disableEnabledToggle}}
                @onToggle={{@controller.toggleEnabled}}
              />
            </span>
          </div>
        </:content>
      </AdminConfigAreaCard>
    {{/if}}

    <AdminConfigAreaCard @heading="discourse_automation.select_script">
      <:content>
        <form class="form-horizontal">
          <FormError @error={{@controller.error}} />

          <section class="form-section edit">
            <div class="control-group">
              <label class="control-label">
                {{i18n "discourse_automation.models.automation.name.label"}}
              </label>

              <div class="controls">
                <DTextField
                  class="input-large"
                  @autofocus={{true}}
                  @input={{withEventValue
                    (fn (mut @controller.automationForm.name))
                  }}
                  @name="automation-name"
                  @type="text"
                  @value={{@controller.automationForm.name}}
                />
              </div>
            </div>

            <div class="control-group">
              <label class="control-label">
                {{i18n "discourse_automation.models.script.name.label"}}
              </label>

              <div class="controls">
                <ComboBox
                  class="scriptables"
                  @content={{@controller.model.scriptables}}
                  @onChange={{@controller.onChangeScript}}
                  @options={{hash filterable=true}}
                  @value={{@controller.automationForm.script}}
                />
              </div>
            </div>
          </section>

          <section class="trigger-section form-section edit">
            <h2 class="title">
              {{i18n
                "discourse_automation.edit_automation.trigger_section.title"
              }}
            </h2>

            <div class="control-group">
              {{#if @controller.model.automation.script.forced_triggerable}}
                <div class="alert alert-warning">
                  {{i18n
                    "discourse_automation.edit_automation.trigger_section.forced"
                  }}
                </div>
              {{/if}}

              <label class="control-label">
                {{i18n "discourse_automation.models.trigger.name.label"}}
              </label>

              <div class="controls">
                <ComboBox
                  class="triggerables"
                  @content={{@controller.model.triggerables}}
                  @onChange={{@controller.onChangeTrigger}}
                  @options={{hash
                    filterable=true
                    none="discourse_automation.select_trigger"
                    disabled=@controller.model.automation.script.forced_triggerable
                  }}
                  @value={{@controller.automationForm.trigger}}
                />
              </div>
            </div>

            {{#if @controller.automationForm.trigger}}
              {{#if @controller.model.automation.trigger.doc}}
                <div class="alert alert-info">
                  <p>{{@controller.model.automation.trigger.doc}}</p>
                </div>
              {{/if}}

              {{#if
                (and
                  @controller.model.automation.enabled
                  @controller.model.automation.trigger.settings.manual_trigger
                )
              }}
                <div class="alert alert-info next-trigger">

                  {{#if @controller.nextPendingAutomationAtFormatted}}
                    <p>
                      {{i18n
                        "discourse_automation.edit_automation.trigger_section.next_pending_automation"
                        date=@controller.nextPendingAutomationAtFormatted
                      }}
                    </p>
                  {{/if}}

                  <DButton
                    class="btn-primary trigger-now-btn"
                    @action={{fn
                      @controller.onManualAutomationTrigger
                      @controller.model.automation.id
                    }}
                    @isLoading={{@controller.isTriggeringAutomation}}
                    @label="discourse_automation.edit_automation.trigger_section.trigger_now"
                  />
                </div>
              {{/if}}

              {{#each @controller.triggerFields as |field|}}
                <AutomationField
                  @automation={{@controller.automation}}
                  @field={{field}}
                  @saveAutomation={{fn
                    @controller.saveAutomation
                    @controller.automation
                  }}
                />
              {{/each}}
            {{/if}}
          </section>

          {{#if @controller.automationForm.trigger}}
            {{#if @controller.scriptFields}}
              <section class="fields-section form-section edit">
                <h2 class="title">
                  {{i18n
                    "discourse_automation.edit_automation.fields_section.title"
                  }}
                </h2>

                {{#if @controller.model.automation.script.with_trigger_doc}}
                  <div class="alert alert-info">
                    <p
                    >{{@controller.model.automation.script.with_trigger_doc}}</p>
                  </div>
                {{/if}}

                <div class="control-group">
                  {{#each @controller.scriptFields as |field|}}
                    <AutomationField
                      @automation={{@controller.automation}}
                      @field={{field}}
                      @saveAutomation={{fn
                        @controller.saveAutomation
                        @controller.automation
                      }}
                    />
                  {{/each}}
                </div>
              </section>
            {{/if}}

            <div class="control-group">
              <DButton
                class="btn-primary update-automation"
                @action={{fn
                  @controller.saveAutomation
                  @controller.automation
                  true
                }}
                @isLoading={{@controller.isUpdatingAutomation}}
                @label="discourse_automation.update"
                @type="submit"
              />
            </div>
          {{/if}}
        </form>
      </:content>
    </AdminConfigAreaCard>
  </div>
</template>
