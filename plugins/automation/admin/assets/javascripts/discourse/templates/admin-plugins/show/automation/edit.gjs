import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ComboBox from "select-kit/components/combo-box";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import FormError from "discourse/plugins/automation/admin/components/form-error";

export default RouteTemplate(
  <template>
    <div
      class="admin-detail discourse-automation-edit discourse-automation-form"
    >
      <BackButton
        @label="discourse_automation.back"
        @route="adminPlugins.show.automation.index"
        class="discourse-automation-back"
      />
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
                  <TextField
                    @value={{@controller.automationForm.name}}
                    @type="text"
                    @autofocus={{true}}
                    @name="automation-name"
                    class="input-large"
                    @input={{withEventValue
                      (fn (mut @controller.automationForm.name))
                    }}
                  />
                </div>
              </div>

              <div class="control-group">
                <label class="control-label">
                  {{i18n "discourse_automation.models.script.name.label"}}
                </label>

                <div class="controls">
                  <ComboBox
                    @value={{@controller.automationForm.script}}
                    @content={{@controller.model.scriptables}}
                    @onChange={{@controller.onChangeScript}}
                    @options={{hash filterable=true}}
                    class="scriptables"
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
                    @value={{@controller.automationForm.trigger}}
                    @content={{@controller.model.triggerables}}
                    @onChange={{@controller.onChangeTrigger}}
                    @options={{hash
                      filterable=true
                      none="discourse_automation.select_trigger"
                      disabled=@controller.model.automation.script.forced_triggerable
                    }}
                    class="triggerables"
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
                      @label="discourse_automation.edit_automation.trigger_section.trigger_now"
                      @isLoading={{@controller.isTriggeringAutomation}}
                      @action={{fn
                        @controller.onManualAutomationTrigger
                        @controller.model.automation.id
                      }}
                      class="btn-primary trigger-now-btn"
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

              {{#if @controller.automationForm.trigger}}
                <div
                  class="control-group automation-enabled alert
                    {{if
                      @controller.automationForm.enabled
                      'alert-info'
                      'alert-warning'
                    }}"
                >
                  <span>{{i18n
                      "discourse_automation.models.automation.enabled.label"
                    }}</span>
                  <Input
                    @type="checkbox"
                    @checked={{@controller.automationForm.enabled}}
                  />
                </div>
              {{/if}}

              <div class="control-group">
                <DButton
                  @isLoading={{@controller.isUpdatingAutomation}}
                  @label="discourse_automation.update"
                  @type="submit"
                  @action={{fn
                    @controller.saveAutomation
                    @controller.automation
                    true
                  }}
                  class="btn-primary update-automation"
                />
              </div>
            {{/if}}
          </form>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
);
