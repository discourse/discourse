import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSecretSelector from "./ai-secret-selector";

export default class AiDecisionModelEditor extends Component {
  @service dialog;
  @service router;
  @service store;
  @service toasts;

  @tracked selectedPreset = null;
  @tracked testError = null;
  @tracked testProbability = null;
  @tracked testResult = null;
  @tracked testRunning = false;

  @cached
  get formData() {
    const record = this.selectedPreset
      ? this.store.createRecord("ai-decision-model", { ...this.selectedPreset })
      : this.args.model;

    return record.createProperties();
  }

  get availableSecrets() {
    return this.args.decisionModels.resultSetMeta.ai_secrets || [];
  }

  get displayTestResult() {
    return this.testRunning || this.testResult !== null;
  }

  get presets() {
    return [
      {
        id: "manual",
        name: i18n("discourse_ai.decision_models.configure_manually"),
        provider: "fake",
      },
      ...this.args.decisionModels.resultSetMeta.presets.map((preset) => ({
        id: preset.preset_id,
        name: preset.display_name,
        provider: preset.provider,
      })),
    ];
  }

  get providers() {
    return this.args.decisionModels.resultSetMeta.providers.map((provider) => ({
      id: provider,
      name: i18n(`discourse_ai.decision_models.providers.${provider}`),
    }));
  }

  get showPresets() {
    return this.args.model.isNew && !this.selectedPreset;
  }

  get testErrorMessage() {
    return i18n("discourse_ai.decision_models.tests.failure", {
      error: this.testError,
    });
  }

  get testSuccessMessage() {
    return i18n("discourse_ai.decision_models.tests.success", {
      percentage: Math.round(this.testProbability * 100),
    });
  }

  @action
  configurePreset(preset) {
    this.selectedPreset =
      this.args.decisionModels.resultSetMeta.presets.find(
        (item) => item.preset_id === preset.id
      ) || {};
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.decision_models.confirm_delete"),
      didConfirm: async () => {
        try {
          await this.args.model.destroyRecord();
          removeValueFromArray(
            this.args.decisionModels.content,
            this.args.model
          );
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-decision-models.index"
          );
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  resetForm() {
    this.selectedPreset = null;
  }

  @action
  async save(data) {
    const isNew = this.args.model.isNew;

    try {
      if (isNew) {
        const record = this.store.createRecord("ai-decision-model", {
          ...data,
        });
        await record.save();
        addUniqueValueToArray(this.args.decisionModels.content, record);
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-decision-models.index"
        );
      } else {
        await this.args.model.save(data);
        this.toasts.success({
          data: { message: i18n("discourse_ai.decision_models.saved") },
          duration: "short",
        });
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async test(data) {
    this.testRunning = true;

    try {
      const result = await this.store
        .createRecord("ai-decision-model", { ...data })
        .testConfig();

      this.testResult = result.success;
      this.testProbability = result.probability;
      this.testError = result.success ? null : result.error;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.testRunning = false;
    }
  }

  <template>
    {{#if this.showPresets}}
      <BackButton
        @label="discourse_ai.decision_models.back"
        @route="adminPlugins.show.discourse-ai-decision-models"
      />
      <div class="control-group">
        <h2>{{i18n "discourse_ai.decision_models.presets"}}</h2>
        <AdminSectionLandingWrapper>
          {{#each this.presets as |preset|}}
            <AdminSectionLandingItem
              class="ai-decision-model-editor__preset"
              data-preset-id={{preset.id}}
              @taglineLabel={{concat
                "discourse_ai.decision_models.providers."
                preset.provider
              }}
              @titleLabelTranslated={{preset.name}}
            >
              <:buttons as |buttons|>
                <buttons.Default
                  @action={{fn this.configurePreset preset}}
                  @icon="gear"
                  @label="discourse_ai.llms.preconfigured.button"
                />
              </:buttons>
            </AdminSectionLandingItem>
          {{/each}}
        </AdminSectionLandingWrapper>
      </div>
    {{else}}
      <Form
        class="form-horizontal ai-decision-model-editor"
        @data={{this.formData}}
        @onSubmit={{this.save}}
        as |form data|
      >
        {{#if @model.isNew}}
          <DButton
            class="btn-flat back-button"
            @action={{this.resetForm}}
            @icon="chevron-left"
            @label="back_button"
          />
        {{else}}
          <BackButton
            @label="discourse_ai.decision_models.back"
            @route="adminPlugins.show.discourse-ai-decision-models"
          />
        {{/if}}

        <form.Field
          class="ai-decision-model-editor__display-name"
          @format="large"
          @name="display_name"
          @title={{i18n "discourse_ai.decision_models.display_name"}}
          @type="input"
          @validation="required|length:1,100"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-decision-model-editor__provider"
          @format="large"
          @name="provider"
          @title={{i18n "discourse_ai.decision_models.provider"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            {{#each this.providers as |provider|}}
              <select.Option
                @value={{provider.id}}
              >{{provider.name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        <form.Field
          class="ai-decision-model-editor__name"
          @description={{i18n "discourse_ai.decision_models.hints.name"}}
          @format="large"
          @name="name"
          @title={{i18n "discourse_ai.decision_models.name"}}
          @type="input"
          @validation="required|length:1,255"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-decision-model-editor__url"
          @description={{i18n "discourse_ai.decision_models.hints.url"}}
          @format="large"
          @name="url"
          @title={{i18n "discourse_ai.decision_models.url"}}
          @type="input"
          @validation="required|length:1,1000"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-decision-model-editor__api-key"
          @description={{i18n "discourse_ai.decision_models.hints.api_key"}}
          @format="large"
          @name="ai_secret_id"
          @title={{i18n "discourse_ai.decision_models.api_key"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <AiSecretSelector
              @onChange={{field.set}}
              @secrets={{this.availableSecrets}}
              @value={{data.ai_secret_id}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          class="ai-decision-model-editor__vision-enabled"
          @format="large"
          @name="vision_enabled"
          @title={{i18n "discourse_ai.decision_models.vision_enabled"}}
          @tooltip={{i18n "discourse_ai.decision_models.hints.vision_enabled"}}
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Actions>
          <form.Submit
            class="ai-decision-model-editor__save"
            @label="discourse_ai.decision_models.save"
          />
          <form.Button
            class="btn-default ai-decision-model-editor__test"
            @action={{fn this.test data}}
            @disabled={{this.testRunning}}
            @label="discourse_ai.decision_models.tests.title"
          />

          {{#unless @model.isNew}}
            <form.Button
              class="btn-danger ai-decision-model-editor__delete"
              @action={{this.delete}}
              @icon="trash-can"
              @label="discourse_ai.decision_models.delete"
            />
          {{/unless}}
        </form.Actions>

        {{#if this.displayTestResult}}
          <form.Container
            class="ai-decision-model-editor__tests"
            @format="full"
          >
            <DConditionalLoadingSpinner
              @condition={{this.testRunning}}
              @size="small"
            >
              {{#if this.testResult}}
                <div class="ai-decision-model-editor__test-success">
                  {{dIcon "check"}}
                  {{this.testSuccessMessage}}
                </div>
              {{else}}
                <div class="ai-decision-model-editor__test-failure">
                  {{dIcon "xmark"}}
                  {{this.testErrorMessage}}
                </div>
              {{/if}}
            </DConditionalLoadingSpinner>
          </form.Container>
        {{/if}}
      </Form>
    {{/if}}
  </template>
}
