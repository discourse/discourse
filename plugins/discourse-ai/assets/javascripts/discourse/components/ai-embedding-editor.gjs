import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, not } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";

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

    presets.unshiftObject({
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
        this.args.embeddings.addObject(newModel);
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
            this.args.embeddings.removeObject(this.args.model);
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
        @route="adminPlugins.show.discourse-ai-embeddings"
        @label="discourse_ai.embeddings.back"
      />
      <div class="control-group">
        <h2>{{i18n "discourse_ai.embeddings.presets"}}</h2>
        <AdminSectionLandingWrapper>
          {{#each this.presets as |preset|}}
            <AdminSectionLandingItem
              @titleLabelTranslated={{preset.name}}
              @taglineLabel={{concat
                "discourse_ai.embeddings.providers."
                preset.provider
              }}
              data-preset-id={{preset.id}}
              class="ai-llms-list-editor__templates-list-item"
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
        @onSubmit={{this.save}}
        @data={{this.formData}}
        class="form-horizontal ai-embedding-editor {{if this.seeded 'seeded'}}"
        as |form data|
      >
        {{#if @model.isNew}}
          <DButton
            @action={{this.resetForm}}
            @label="back_button"
            @icon="chevron-left"
            class="btn-flat back-button"
          />
        {{else}}
          <BackButton
            @route="adminPlugins.show.discourse-ai-embeddings"
            @label="discourse_ai.embeddings.back"
          />
        {{/if}}

        <form.Field
          @name="display_name"
          @title={{i18n "discourse_ai.embeddings.display_name"}}
          @validation="required|length:1,100"
          @format="large"
          class="ai-embedding-editor__display-name"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="provider"
          @title={{i18n "discourse_ai.embeddings.provider"}}
          @validation="required"
          @format="large"
          @onSet={{this.setProvider}}
          class="ai-embedding-editor__provider"
          as |field|
        >
          <field.Select as |select|>
            {{#each this.selectedProviders as |provider|}}
              <select.Option
                @value={{provider.id}}
              >{{provider.name}}</select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @name="url"
          @title={{i18n "discourse_ai.embeddings.url"}}
          @validation="required"
          @format="large"
          class="ai-embedding-editor__url"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="api_key"
          @title={{i18n "discourse_ai.embeddings.api_key"}}
          @validation="required"
          @format="large"
          class="ai-embedding-editor__api-key"
          as |field|
        >
          <field.Password />
        </form.Field>

        <form.Field
          @name="tokenizer_class"
          @title={{i18n "discourse_ai.embeddings.tokenizer"}}
          @validation="required"
          @format="large"
          class="ai-embedding-editor__tokenizer"
          as |field|
        >
          <field.Select as |select|>
            {{#each @embeddings.resultSetMeta.tokenizers as |tokenizer|}}
              <select.Option
                @value={{tokenizer.id}}
              >{{tokenizer.name}}</select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @name="dimensions"
          @title={{i18n "discourse_ai.embeddings.dimensions"}}
          @validation="required"
          @format="large"
          @tooltip={{if
            @model.isNew
            (i18n "discourse_ai.embeddings.hints.dimensions_warning")
          }}
          class="ai-embedding-editor__dimensions"
          as |field|
        >
          <field.Input
            @type="number"
            step="any"
            min="0"
            lang="en"
            disabled={{not @model.isNew}}
          />
        </form.Field>

        <form.Field
          @name="matryoshka_dimensions"
          @title={{i18n "discourse_ai.embeddings.matryoshka_dimensions"}}
          @tooltip={{i18n
            "discourse_ai.embeddings.hints.matryoshka_dimensions"
          }}
          @format="large"
          class="ai-embedding-editor__matryoshka_dimensions"
          as |field|
        >
          <field.Checkbox />
        </form.Field>

        <form.Field
          @name="embed_prompt"
          @title={{i18n "discourse_ai.embeddings.embed_prompt"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.embed_prompt"}}
          @format="large"
          class="ai-embedding-editor__embed_prompt"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <form.Field
          @name="search_prompt"
          @title={{i18n "discourse_ai.embeddings.search_prompt"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.search_prompt"}}
          @format="large"
          class="ai-embedding-editor__search_prompt"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <form.Field
          @name="max_sequence_length"
          @title={{i18n "discourse_ai.embeddings.max_sequence_length"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.sequence_length"}}
          @validation="required"
          @format="large"
          class="ai-embedding-editor__max_sequence_length"
          as |field|
        >
          <field.Input @type="number" step="any" min="0" lang="en" />
        </form.Field>

        <form.Field
          @name="pg_function"
          @title={{i18n "discourse_ai.embeddings.distance_function"}}
          @tooltip={{i18n "discourse_ai.embeddings.hints.distance_function"}}
          @format="large"
          @validation="required"
          class="ai-embedding-editor__distance_functions"
          as |field|
        >
          <field.Select @includeNone={{false}} as |select|>
            {{#each this.distanceFunctions as |df|}}
              <select.Option @value={{df.id}}>{{df.name}}</select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        {{! provider-specific content }}
        {{#if this.currentProvider}}
          <form.Object @name="provider_params" as |object providerData|>
            {{#each (this.providerKeys providerData) as |name|}}
              {{#let (get this.providerParams name) as |params|}}
                {{#if params}}
                  <object.Field
                    @name={{name}}
                    @title={{i18n
                      (concat "discourse_ai.embeddings.provider_fields." name)
                    }}
                    @format="large"
                    @validation="required"
                    class="ai-embedding-editor-provider-param__{{params.type}}"
                    as |field|
                  >
                    {{#if (eq params.type "enum")}}
                      <field.Select @includeNone={{false}} as |select|>
                        {{#each params.values as |option|}}
                          <select.Option
                            @value={{option.id}}
                          >{{option.name}}</select.Option>
                        {{/each}}
                      </field.Select>
                    {{else if (eq params.type "checkbox")}}
                      <field.Checkbox />
                    {{else}}
                      <field.Input @type={{params.type}} />
                    {{/if}}
                  </object.Field>
                {{/if}}
              {{/let}}
            {{/each}}
          </form.Object>
        {{/if}}

        <form.Actions class="ai-embedding-editor__action_panel">
          <form.Button
            @action={{fn this.test data}}
            @disabled={{this.testRunning}}
            @label="discourse_ai.embeddings.tests.title"
            class="ai-embedding-editor__test"
          />

          <form.Submit
            @label="discourse_ai.embeddings.save"
            class="btn-primary ai-embedding-editor__save"
          />

          {{#unless data.isNew}}
            <form.Button
              @action={{this.delete}}
              @label="discourse_ai.embeddings.delete"
              class="btn-danger ai-embedding-editor__delete"
            />
          {{/unless}}
        </form.Actions>

        {{#if this.displayTestResult}}
          <form.Container @format="full" class="ai-embedding-editor-tests">
            <ConditionalLoadingSpinner
              @size="small"
              @condition={{this.testRunning}}
            >
              {{#if this.testResult}}
                <div class="ai-embedding-editor-tests__success">
                  {{icon "check"}}
                  {{i18n "discourse_ai.embeddings.tests.success"}}
                </div>
              {{else}}
                <div class="ai-embedding-editor-tests__failure">
                  {{icon "xmark"}}
                  {{this.testErrorMessage}}
                </div>
              {{/if}}
            </ConditionalLoadingSpinner>
          </form.Container>
        {{/if}}
      </Form>
    {{/if}}
  </template>
}
