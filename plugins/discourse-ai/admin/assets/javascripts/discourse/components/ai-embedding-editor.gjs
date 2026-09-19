/* eslint-disable ember/no-side-effects */
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
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
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSecretSelector from "./ai-secret-selector";

export default class AiEmbeddingEditor extends Component {
  @service toasts;
  @service router;
  @service dialog;
  @service store;

  @tracked isSaving = false;
  @tracked selectedPreset = null;
  @tracked testRunning = false;
  @tracked testResult = null;
  @tracked testError = null;
  @tracked currentProvider = null;

  constructor() {
    super(...arguments);
    if (this.args.model) {
      this.currentProvider = this.args.model.provider;
    }
  }

  @cached
  get formData() {
    let data;

    if (this.selectedPreset) {
      data = this.store
        .createRecord("ai-embedding", this.selectedPreset)
        .workingCopy();
    } else {
      data = this.args.model.workingCopy();
    }

    const originalData = JSON.parse(JSON.stringify(data));
    this._originalFormData = originalData;

    return originalData;
  }

  get availableSecrets() {
    return this.args.embeddings?.resultSetMeta?.ai_secrets || [];
  }

  get selectedProviders() {
    const t = (provName) => {
      return i18n(`discourse_ai.embeddings.providers.${provName}`);
    };

    return this.args.embeddings.resultSetMeta.providers.map((prov) => {
      return { id: prov, name: t(prov) };
    });
  }

  get distanceFunctions() {
    const t = (df) => {
      return i18n(`discourse_ai.embeddings.distance_functions.${df}`);
    };

    return this.args.embeddings.resultSetMeta.distance_functions.map((df) => {
      return {
        id: df,
        name: t(df),
      };
    });
  }

  get presets() {
    const presets = this.args.embeddings.resultSetMeta.presets.map((preset) => {
      return {
        name: preset.display_name,
        id: preset.preset_id,
        provider: preset.provider,
      };
    });

    presets.unshift({
      name: i18n("discourse_ai.embeddings.configure_manually"),
      id: "manual",
      provider: "fake",
    });

    return presets;
  }

  get showPresets() {
    return !this.selectedPreset && this.args.model.isNew;
  }

  get metaProviderParams() {
    const provider = this.currentProvider;
    if (!provider) {
      return {};
    }

    const embeddings = this.args.embeddings || {};
    const meta = embeddings.resultSetMeta || {};
    const providerParams = meta.provider_params || {};

    return providerParams[provider] || {};
  }

  get testErrorMessage() {
    return i18n("discourse_ai.llms.tests.failure", { error: this.testError });
  }

  get displayTestResult() {
    return this.testRunning || this.testResult !== null;
  }

  get seeded() {
    return this.args.model.id < 0;
  }

  get providerParams() {
    const normalizeParam = (value) => {
      if (!value) {
        return { type: "text" };
      }

      if (typeof value === "string") {
        return { type: value };
      }

      return {
        type: value.type || "text",
        values: (value.values || []).map((v) => ({ id: v, name: v })),
        default: value.default,
      };
    };

    return Object.entries(this.metaProviderParams).reduce(
      (acc, [field, value]) => {
        acc[field] = normalizeParam(value);
        return acc;
      },
      {}
    );
  }

  fieldTypeForProviderParam(type) {
    switch (type) {
      case "enum":
        return "select";
      case "checkbox":
        return "checkbox";
      default:
        return `input-${type}`;
    }
  }

  @action
  configurePreset(preset) {
    this.selectedPreset =
      this.args.embeddings.resultSetMeta.presets.find(
        (item) => item.preset_id === preset.id
      ) || {};

    if (this.selectedPreset.provider) {
      this.currentProvider = this.selectedPreset.provider;
    }
  }

  @action
  setProvider(provider, { set }) {
    set("provider", provider);

    this.currentProvider = provider;

    const providerParams =
      this.args.embeddings?.resultSetMeta?.provider_params || {};
    const params = providerParams[provider] || {};

    const initialParams = {};

    if (params) {
      const keys = Object.keys(params);
      keys.forEach((key) => {
        initialParams[key] = null;
      });
    }

    set("provider_params", initialParams);
  }

  @action
  resetForm() {
    this.selectedPreset = null;
    this.currentProvider = null;
  }

  @action
  async save(formData) {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    try {
      const dataToSave = { ...formData };

      if (this.selectedPreset) {
        // new embeddings
        const newModel = this.store.createRecord("ai-embedding", {
          ...this.selectedPreset,
          ...dataToSave,
        });
        await newModel.save();
        addUniqueValueToArray(this.args.embeddings.content, newModel);
      } else {
        // existing embeddings
        await this.args.model.save(dataToSave);
      }

      if (isNew) {
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-embeddings.index"
        );
      } else {
        const savedProvider = this.currentProvider;

        this._originalFormData = JSON.parse(JSON.stringify(dataToSave));
        this.currentProvider = savedProvider;

        this.toasts.success({
          data: { message: i18n("discourse_ai.embeddings.saved") },
          duration: "short",
        });
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  @action
  async test(data) {
    this.testRunning = true;

    try {
      let testModel;

      // new embeddings
      if (this.args.model.isNew || this.selectedPreset) {
        testModel = this.store.createRecord("ai-embedding", {
          ...this.selectedPreset,
          ...data,
        });
      } else {
        // existing embeddings
        testModel = this.args.model;
      }

      const configTestResult = await testModel.testConfig(data);
      this.testResult = configTestResult.success;

      if (this.testResult) {
        this.testError = null;
      } else {
        this.testError = configTestResult.error;
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.testRunning = false;
      }, 1000);
    }
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.embeddings.confirm_delete"),
      didConfirm: () => {
        return this.args.model
          .destroyRecord()
          .then(() => {
            removeValueFromArray(this.args.embeddings, this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-embeddings.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  providerKeys(providerParams) {
    return providerParams ? Object.keys(providerParams) : [];
  }

  <template>
    {{#if this.showPresets}}
      <BackButton
        @label="discourse_ai.embeddings.back"
        @route="adminPlugins.show.discourse-ai-embeddings"
      />
      <div class="control-group">
        <h2>{{i18n "discourse_ai.embeddings.presets"}}</h2>
        <AdminSectionLandingWrapper>
          {{#each this.presets as |preset|}}
            <AdminSectionLandingItem
              class="ai-llms-list-editor__templates-list-item"
              data-preset-id={{preset.id}}
              @taglineLabel={{concat
                "discourse_ai.embeddings.providers."
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
        class="form-horizontal ai-embedding-editor {{if this.seeded 'seeded'}}"
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
            @label="discourse_ai.embeddings.back"
            @route="adminPlugins.show.discourse-ai-embeddings"
          />
        {{/if}}

        <form.Field
          class="ai-embedding-editor__display-name"
          @format="large"
          @name="display_name"
          @title={{i18n "discourse_ai.embeddings.display_name"}}
          @type="input"
          @validation="required|length:1,100"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__provider"
          @format="large"
          @name="provider"
          @onSet={{this.setProvider}}
          @title={{i18n "discourse_ai.embeddings.provider"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            {{#each this.selectedProviders as |provider|}}
              <select.Option
                @value={{provider.id}}
              >{{provider.name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        <form.Field
          class="ai-embedding-editor__url"
          @format="large"
          @name="url"
          @title={{i18n "discourse_ai.embeddings.url"}}
          @type="input"
          @validation="required"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__api-key"
          @format="large"
          @name="ai_secret_id"
          @title={{i18n "discourse_ai.embeddings.api_key"}}
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
          class="ai-embedding-editor__tokenizer"
          @format="large"
          @name="tokenizer_class"
          @title={{i18n "discourse_ai.embeddings.tokenizer"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            {{#each @embeddings.resultSetMeta.tokenizers as |tokenizer|}}
              <select.Option
                @value={{tokenizer.id}}
              >{{tokenizer.name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        <form.Field
          class="ai-embedding-editor__dimensions"
          @format="large"
          @name="dimensions"
          @title={{i18n "discourse_ai.embeddings.dimensions"}}
          @tooltip={{if
            @model.isNew
            (i18n "discourse_ai.embeddings.hints.dimensions_warning")
          }}
          @type="input-number"
          @validation="required"
          as |field|
        >
          <field.Control
            disabled={{not @model.isNew}}
            lang="en"
            min="0"
            step="any"
          />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__matryoshka_dimensions"
          @format="large"
          @name="matryoshka_dimensions"
          @title={{i18n "discourse_ai.embeddings.matryoshka_dimensions"}}
          @tooltip={{i18n
            "discourse_ai.embeddings.hints.matryoshka_dimensions"
          }}
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__embed_prompt"
          @format="large"
          @name="embed_prompt"
          @title={{i18n "discourse_ai.embeddings.embed_prompt"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.embed_prompt"}}
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__search_prompt"
          @format="large"
          @name="search_prompt"
          @title={{i18n "discourse_ai.embeddings.search_prompt"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.search_prompt"}}
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__max_sequence_length"
          @format="large"
          @name="max_sequence_length"
          @title={{i18n "discourse_ai.embeddings.max_sequence_length"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.sequence_length"}}
          @type="input-number"
          @validation="required"
          as |field|
        >
          <field.Control lang="en" min="0" step="any" />
        </form.Field>

        <form.Field
          class="ai-embedding-editor__distance_functions"
          @format="large"
          @name="pg_function"
          @title={{i18n "discourse_ai.embeddings.distance_function"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.distance_function"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            {{#each this.distanceFunctions as |df|}}
              <select.Option @value={{df.id}}>{{df.name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        {{! provider-specific content }}
        {{#if this.currentProvider}}
          <form.Object @name="provider_params" as |object providerData|>
            {{#each (this.providerKeys providerData) as |name|}}
              {{#let (get this.providerParams name) as |params|}}
                {{#if params}}
                  <object.Field
                    class="ai-embedding-editor-provider-param__{{params.type}}"
                    @format="large"
                    @name={{name}}
                    @title={{i18n
                      (concat "discourse_ai.embeddings.provider_fields." name)
                    }}
                    @type={{this.fieldTypeForProviderParam params.type}}
                    @validation="required"
                    as |field|
                  >
                    {{#if (eq params.type "enum")}}
                      <field.Control @includeNone={{false}} as |select|>
                        {{#each params.values as |option|}}
                          <select.Option
                            @value={{option.id}}
                          >{{option.name}}</select.Option>
                        {{/each}}
                      </field.Control>
                    {{else if (eq params.type "checkbox")}}
                      <field.Control />
                    {{else}}
                      <field.Control />
                    {{/if}}
                  </object.Field>
                {{/if}}
              {{/let}}
            {{/each}}
          </form.Object>
        {{/if}}

        <form.Actions class="ai-embedding-editor__action_panel">
          <form.Submit
            class="btn-primary ai-embedding-editor__save"
            @label="discourse_ai.embeddings.save"
          />
          <form.Button
            class="btn-default ai-embedding-editor__test"
            @action={{fn this.test data}}
            @disabled={{this.testRunning}}
            @label="discourse_ai.embeddings.tests.title"
          />

          {{#unless data.isNew}}
            <form.Button
              class="btn-danger ai-embedding-editor__delete"
              @action={{this.delete}}
              @icon="trash-can"
              @label="discourse_ai.embeddings.delete"
            />
          {{/unless}}
        </form.Actions>

        {{#if this.displayTestResult}}
          <form.Container class="ai-embedding-editor-tests" @format="full">
            <DConditionalLoadingSpinner
              @condition={{this.testRunning}}
              @size="small"
            >
              {{#if this.testResult}}
                <div class="ai-embedding-editor-tests__success">
                  {{dIcon "check"}}
                  {{i18n "discourse_ai.embeddings.tests.success"}}
                </div>
              {{else}}
                <div class="ai-embedding-editor-tests__failure">
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
