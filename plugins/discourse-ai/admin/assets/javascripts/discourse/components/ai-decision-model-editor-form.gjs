import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";
import AiSecretSelector from "discourse/plugins/discourse-ai/discourse/components/ai-secret-selector";

function presetFields(preset) {
  return {
    display_name: preset.display_name,
    name: preset.name,
    provider: preset.provider,
    url: preset.url,
    vision_enabled: preset.vision_enabled,
    custom_headers: (preset.custom_headers ?? []).map((header) => ({
      ...header,
    })),
  };
}

export default class AiDecisionModelEditorForm extends Component {
  @service dialog;
  @service router;
  @service toasts;

  @tracked testResult = null;
  @tracked testRunning = false;

  @cached
  get formData() {
    const { model } = this.args;
    const data = {
      display_name: model.display_name,
      name: model.name,
      provider: model.provider || this.providers[0],
      url: model.url,
      ai_secret_id: model.ai_secret_id,
      vision_enabled: model.vision_enabled ?? false,
      custom_headers: model.custom_headers ?? [],
    };

    const preset =
      model.isNew &&
      this.presets.find((item) => item.preset_id === this.args.preset);
    if (preset) {
      Object.assign(data, presetFields(preset), {
        preset: preset.preset_id,
      });
    }

    return data;
  }

  get customHeaderLimits() {
    return this.args.decisionModels.resultSetMeta.custom_header_limits;
  }

  get presets() {
    return this.args.decisionModels.resultSetMeta.presets;
  }

  get providers() {
    return this.args.decisionModels.resultSetMeta.providers;
  }

  get secrets() {
    return this.args.decisionModels.resultSetMeta.ai_secrets;
  }

  get testPercentage() {
    return Math.round(this.testResult.probability * 100);
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
            "adminPlugins.show.discourse-ai-models.index"
          );
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async save(data) {
    const isNew = this.args.model.isNew;

    try {
      await this.args.model.save(data);

      if (isNew) {
        addUniqueValueToArray(
          this.args.decisionModels.content,
          this.args.model
        );
        this.router.replaceWith(
          "adminPlugins.show.discourse-ai-decision-models.edit",
          this.args.model.id
        );
      }

      this.toasts.success({
        data: { message: i18n("discourse_ai.decision_models.saved") },
        duration: "short",
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async selectPreset(value, { set }) {
    await set("preset", value);
    const preset = this.presets.find((item) => item.preset_id === value);
    if (preset) {
      const { provider, custom_headers, ...fields } = presetFields(preset);
      for (const [name, fieldValue] of Object.entries(fields)) {
        await set(name, fieldValue);
      }
      await this.selectProvider(provider, { set });
      await set("custom_headers", custom_headers);
    }
    this.testResult = null;
  }

  @action
  async selectProvider(value, { set }) {
    await set("provider", value);
    if (!["system_one", "typesafe"].includes(value)) {
      await set("custom_headers", []);
    }
    this.testResult = null;
  }

  @action
  async test(data) {
    this.testRunning = true;

    try {
      this.testResult = await this.args.model.testConfig(data);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.testRunning = false;
    }
  }

  <template>
    <BackButton
      @label="discourse_ai.models.back"
      @route="adminPlugins.show.discourse-ai-models"
    />
    <Form
      class="ai-decision-model-editor"
      @data={{this.formData}}
      @onSubmit={{this.save}}
      as |form data|
    >
      {{#if @model.isNew}}
        <form.Field
          @name="preset"
          @onSet={{this.selectPreset}}
          @title={{i18n "discourse_ai.decision_models.start_from"}}
          @type="select"
          as |field|
        >
          <field.Control
            @nonePlaceholder={{i18n "discourse_ai.decision_models.no_preset"}}
            as |select|
          >
            {{#each this.presets as |preset|}}
              <select.Option
                @value={{preset.preset_id}}
              >{{preset.display_name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
      {{/if}}
      <form.Field
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
        @format="large"
        @name="provider"
        @onSet={{this.selectProvider}}
        @title={{i18n "discourse_ai.decision_models.provider"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control @includeNone={{false}} as |select|>
          {{#each this.providers as |option|}}
            <select.Option @value={{option}}>
              {{i18n (concat "discourse_ai.decision_models.providers." option)}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      <form.Field
        @format="large"
        @name="name"
        @title={{i18n "discourse_ai.decision_models.model"}}
        @type="input"
        @validation="required|length:1,255"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
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
        @format="large"
        @name="ai_secret_id"
        @title={{i18n "discourse_ai.decision_models.api_key"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <AiSecretSelector
            @onChange={{field.set}}
            @secrets={{this.secrets}}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>

      {{#if (or (eq data.provider "system_one") (eq data.provider "typesafe"))}}
        <form.Container @direction="column" @format="large">
          <form.Section
            @title={{i18n "discourse_ai.decision_models.custom_headers.title"}}
          >
            <form.Collection @name="custom_headers" as |collection index|>
              <form.Fieldset>
                <collection.Field
                  @format="large"
                  @name="name"
                  @title={{i18n
                    "discourse_ai.decision_models.custom_headers.name"
                  }}
                  @type="input"
                  @validation={{concat
                    "required|length:1,"
                    this.customHeaderLimits.name_length
                  }}
                  as |field|
                >
                  <field.Control />
                </collection.Field>

                <collection.Field
                  @format="large"
                  @name="value"
                  @title={{i18n
                    "discourse_ai.decision_models.custom_headers.value"
                  }}
                  @type="input"
                  @validation={{concat
                    "length:0,"
                    this.customHeaderLimits.value_length
                  }}
                  as |field|
                >
                  <field.Control />
                </collection.Field>
                <form.Actions>
                  <form.Button
                    class="btn-default ai-decision-model-editor__remove-header"
                    @action={{fn collection.remove index}}
                    @icon="trash-can"
                    @title="discourse_ai.decision_models.custom_headers.remove"
                  />
                </form.Actions>
              </form.Fieldset>
            </form.Collection>
            <form.Actions>
              <form.Button
                class="btn-default ai-decision-model-editor__add-header"
                @action={{fn
                  form.addItemToCollection
                  "custom_headers"
                  (hash name="" value="")
                }}
                @disabled={{gte
                  data.custom_headers.length
                  this.customHeaderLimits.count
                }}
                @icon="plus"
                @label="discourse_ai.decision_models.custom_headers.add"
              />
            </form.Actions>
          </form.Section>
        </form.Container>
      {{/if}}

      <form.Field
        @format="large"
        @name="vision_enabled"
        @showTitle={{false}}
        @title={{i18n "discourse_ai.decision_models.vision_enabled"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Actions>
        <form.Submit />
        <form.Button
          class="btn-default ai-decision-model-editor__test-btn"
          @action={{fn this.test data}}
          @isLoading={{this.testRunning}}
          @label="discourse_ai.decision_models.test"
        />
        {{#unless @model.isNew}}
          <form.Button
            class="btn-danger ai-decision-model-editor__delete-btn"
            @action={{this.delete}}
            @label="discourse_ai.decision_models.delete"
          />
        {{/unless}}
      </form.Actions>

      {{#if this.testResult}}
        {{#if this.testResult.success}}
          <form.Alert
            class="ai-decision-model-editor__test-result"
            @icon="check"
            @type="success"
          >
            {{i18n
              "discourse_ai.decision_models.test_success"
              percentage=this.testPercentage
            }}
          </form.Alert>
        {{else}}
          <form.Alert
            class="ai-decision-model-editor__test-result"
            @icon="xmark"
            @type="error"
          >
            {{this.testResult.error}}
          </form.Alert>
        {{/if}}
      {{/if}}
    </Form>
  </template>
}
