import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import AdminUser from "discourse/admin/models/admin-user";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { groupPath } from "discourse/lib/url";
import { eq, gt, not } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiLlmAttachmentTypes from "discourse/plugins/discourse-ai/discourse/components/ai-llm-attachment-types";
import AiLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-llm-selector";
import {
  isProviderParamHidden,
  normalizeProviderParams,
  providerParamLabel,
} from "discourse/plugins/discourse-ai/discourse/lib/llm-provider-param-helpers";
import DurationSelector from "./ai-quota-duration-selector";
import AiSecretSelector from "./ai-secret-selector";
import AiLlmQuotaModal from "./modal/ai-llm-quota-modal";

export default class AiLlmEditorForm extends Component {
  @service toasts;
  @service router;
  @service dialog;
  @service modal;

  @tracked isSaving = false;
  @tracked testRunning = false;
  @tracked testResult = null;
  @tracked testError = null;
  @tracked testValidationErrors = null;
  @tracked testFailedMode = null;

  @cached
  get formData() {
    if (this.args.llmTemplate) {
      let [id, modelName] = this.args.llmTemplate.split(/-(.*)/);
      if (id === "none") {
        return { provider_params: {} };
      }

      const info = this.args.llms.resultSetMeta.presets.find(
        (item) => item.id === id
      );
      const modelInfo = info.models.find((item) => item.name === modelName);

      return {
        max_prompt_tokens: modelInfo.tokens,
        max_output_tokens: modelInfo.max_output_tokens,
        tokenizer: info.tokenizer,
        url: modelInfo.endpoint || info.endpoint,
        display_name: modelInfo.display_name,
        name: modelInfo.name,
        provider: info.provider,
        provider_params: this.computeProviderParams(
          info.provider,
          modelInfo.provider_params ?? {}
        ),
        input_cost: modelInfo.input_cost,
        output_cost: modelInfo.output_cost,
        cached_input_cost: modelInfo.cached_input_cost,
        vision_enabled: modelInfo.vision_enabled || false,
        vision_mode: modelInfo.vision_enabled ? "native" : "disabled",
        vision_llm_model_id: null,
        cache_write_cost: modelInfo.cache_write_cost,
        allowed_attachment_types: [],
      };
    }

    const { model } = this.args;

    return {
      max_prompt_tokens: model.max_prompt_tokens,
      max_output_tokens: model.max_output_tokens,
      ai_secret_id: model.ai_secret_id,
      tokenizer: model.tokenizer,
      url: model.url,
      display_name: model.display_name,
      name: model.name,
      provider: model.provider,
      vision_enabled: model.vision_enabled,
      vision_mode:
        model.vision_mode ?? (model.vision_enabled ? "native" : "disabled"),
      vision_llm_model_id: model.vision_llm_model_id,
      input_cost: model.input_cost,
      output_cost: model.output_cost,
      cached_input_cost: model.cached_input_cost,
      cache_write_cost: model.cache_write_cost,
      provider_params: this.computeProviderParams(
        model.provider,
        model.provider_params
      ),
      llm_quotas: model.llm_quotas,
      allowed_attachment_types: model.allowed_attachment_types || [],
    };
  }

  get availableSecrets() {
    return this.args.llms.resultSetMeta?.ai_secrets || [];
  }

  get nativeVisionModels() {
    return this.args.llms.content
      .filter(
        (llm) =>
          llm.id !== this.args.model.id &&
          llm.vision_enabled &&
          (llm.vision_mode ?? "native") === "native"
      )
      .map((llm) => ({
        id: llm.id,
        name: `${llm.display_name} — ${i18n(
          `discourse_ai.llms.providers.${llm.provider}`
        )}`,
      }))
      .sort((first, second) => first.name.localeCompare(second.name));
  }

  get selectedProviders() {
    const t = (provName) => {
      return i18n(`discourse_ai.llms.providers.${provName}`);
    };

    return this.args.llms.resultSetMeta.providers
      .map((prov) => {
        return { id: prov, name: t(prov) };
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  get tokenizers() {
    return this.args.llms.resultSetMeta.tokenizers.sort((a, b) =>
      a.name.localeCompare(b.name)
    );
  }

  get adminUser() {
    return AdminUser.create(this.args.model?.user);
  }

  get testErrorMessage() {
    if (this.testValidationErrors?.length > 0) {
      return i18n("discourse_ai.llms.tests.invalid_config");
    }

    if (this.testFailedMode) {
      return i18n(`discourse_ai.llms.tests.failure_${this.testFailedMode}`, {
        error: this.testError,
      });
    }

    return i18n("discourse_ai.llms.tests.failure", { error: this.testError });
  }

  get displayTestResult() {
    return this.testRunning || this.testResult !== null;
  }

  get modulesUsingModel() {
    const usedBy = this.args.model.used_by?.filter((m) => m.type !== "ai_bot");

    if (!usedBy || usedBy.length === 0) {
      return null;
    }

    const localized = usedBy.map((m) => {
      return i18n(`discourse_ai.llms.usage.${m.type}`, {
        agent: m.name,
      });
    });

    // TODO: this is not perfectly localized
    return localized.join(", ");
  }

  get inUseWarning() {
    return i18n("discourse_ai.llms.in_use_warning", {
      settings: this.modulesUsingModel,
      count: this.args.model.used_by.length,
    });
  }

  fieldTypeForProviderParam(type) {
    switch (type) {
      case "enum":
        return "select";
      case "checkbox":
        return "checkbox";
      case "secret":
        return "custom";
      default:
        return `input-${type}`;
    }
  }

  computeProviderParams(provider, currentParams = {}) {
    const params = this.args.llms.resultSetMeta.provider_params[provider] ?? {};
    return Object.fromEntries(
      Object.entries(params).map(([k, v]) => [
        k,
        currentParams[k] ?? (v?.type === "enum" ? v.default : null),
      ])
    );
  }

  @action
  canEditURL(provider) {
    const capabilities =
      this.args.llms.resultSetMeta.provider_capabilities?.[provider];
    return capabilities?.requires_configured_url ?? true;
  }

  @action
  openAddQuotaModal(addItemToCollection) {
    this.modal.show(AiLlmQuotaModal, {
      model: { llm: this.args.model, addItemToCollection },
    });
  }

  @action
  metaProviderParams(provider) {
    const params = this.args.llms.resultSetMeta.provider_params[provider] || {};
    return normalizeProviderParams(params);
  }

  @action
  async save(data) {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    const updatedData = {
      ...data,
    };

    // If max_prompt_tokens input is cleared,
    // we want the db to store null
    if (!data.max_output_tokens) {
      updatedData.max_output_tokens = null;
    }

    try {
      await this.args.model.save(updatedData);

      if (isNew) {
        addUniqueValueToArray(this.args.llms.content, this.args.model);
        await this.router.replaceWith(
          "adminPlugins.show.discourse-ai-llms.edit",
          this.args.model.id
        );
      }
      this.toasts.success({
        data: { message: i18n("discourse_ai.llms.saved") },
        duration: "short",
      });
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
      // For seeded models, include the id so backend can test the existing model
      const testData = this.args.model.seeded
        ? { ...data, id: this.args.model.id }
        : data;
      const configTestResult = await this.args.model.testConfig(testData);
      this.testResult = configTestResult.success;

      if (this.testResult) {
        this.testError = null;
        this.testValidationErrors = null;
        this.testFailedMode = null;
      } else {
        this.testError = configTestResult.error;
        this.testValidationErrors = configTestResult.validation_errors;
        this.testFailedMode = configTestResult.failed_mode;
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
  setVisionMode(mode, { set }) {
    set("vision_mode", mode);
    if (mode !== "delegated") {
      set("vision_llm_model_id", null);
    }
  }

  @action
  setProvider(provider, { set }) {
    set("provider_params", this.computeProviderParams(provider));
    set("provider", provider);
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.llms.confirm_delete"),
      didConfirm: () => {
        return this.args.model
          .destroyRecord()
          .then(() => {
            removeValueFromArray(this.args.llms.content, this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-llms.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  isProviderParamHidden(params, providerParamsData) {
    return isProviderParamHidden(params, providerParamsData);
  }

  @action
  providerParamsKeys(providerParams) {
    return providerParams ? Object.keys(providerParams) : [];
  }

  <template>
    <Form
      class="ai-llm-editor"
      @data={{this.formData}}
      @onSubmit={{this.save}}
      as |form data|
    >
      {{#if this.modulesUsingModel}}
        <form.Alert @icon="circle-info">
          {{this.inUseWarning}}
        </form.Alert>
      {{/if}}

      <form.Field
        @disabled={{@model.seeded}}
        @format="large"
        @name="display_name"
        @title={{i18n "discourse_ai.llms.display_name"}}
        @tooltip={{i18n "discourse_ai.llms.hints.display_name"}}
        @type="input"
        @validation="required|length:1,100"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @disabled={{@model.seeded}}
        @format="large"
        @name="name"
        @title={{i18n "discourse_ai.llms.name"}}
        @tooltip={{i18n "discourse_ai.llms.hints.name"}}
        @type="input"
        @validation="required"
        as |field|
      >
        <field.Control />
      </form.Field>

      {{#unless @model.seeded}}
        <form.Field
          @format="large"
          @name="provider"
          @onSet={{this.setProvider}}
          @title={{i18n "discourse_ai.llms.provider"}}
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

        {{#if (this.canEditURL data.provider)}}
          <form.Field
            @format="large"
            @name="url"
            @title={{i18n "discourse_ai.llms.url"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        <form.Field
          @format="large"
          @name="ai_secret_id"
          @title={{i18n "discourse_ai.llms.api_key"}}
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

        <form.Object @name="provider_params" as |object providerParamsData|>
          {{#each (this.providerParamsKeys providerParamsData) as |name|}}
            {{#let
              (get (this.metaProviderParams data.provider) name)
              as |params|
            }}
              {{#if
                (not (this.isProviderParamHidden params providerParamsData))
              }}
                <object.Field
                  @format="large"
                  @helpText={{if params.helpText (i18n params.helpText)}}
                  @name={{name}}
                  @showTitle={{not (eq params.type "checkbox")}}
                  @title={{i18n (providerParamLabel name params)}}
                  @tooltip={{if params.tooltip (i18n params.tooltip)}}
                  @type={{this.fieldTypeForProviderParam params.type}}
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
                  {{else if (eq params.type "secret")}}
                    <field.Control>
                      <AiSecretSelector
                        @onChange={{field.set}}
                        @secrets={{this.availableSecrets}}
                        @value={{field.value}}
                      />
                    </field.Control>
                  {{else}}
                    <field.Control />
                  {{/if}}
                </object.Field>
              {{/if}}
            {{/let}}
          {{/each}}
        </form.Object>

        <form.Field
          @format="large"
          @name="tokenizer"
          @title={{i18n "discourse_ai.llms.tokenizer"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            {{#each this.tokenizers as |tokenizer|}}
              <select.Option
                @value={{tokenizer.id}}
              >{{tokenizer.name}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        <form.Field
          @format="large"
          @name="max_prompt_tokens"
          @title={{i18n "discourse_ai.llms.max_prompt_tokens"}}
          @tooltip={{i18n "discourse_ai.llms.hints.max_prompt_tokens"}}
          @type="input-number"
          @validation="required"
          as |field|
        >
          <field.Control lang="en" min="0" step="any" />
        </form.Field>

        <form.InputGroup as |inputGroup|>
          <inputGroup.Field
            @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
            @name="input_cost"
            @title={{i18n "discourse_ai.llms.cost_input"}}
            @tooltip={{i18n "discourse_ai.llms.hints.cost_input"}}
            @type="input-number"
            as |field|
          >
            <field.Control lang="en" min="0" step="any" />
          </inputGroup.Field>

          <inputGroup.Field
            @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
            @name="output_cost"
            @title={{i18n "discourse_ai.llms.cost_output"}}
            @tooltip={{i18n "discourse_ai.llms.hints.cost_output"}}
            @type="input-number"
            as |field|
          >
            <field.Control lang="en" min="0" step="any" />
          </inputGroup.Field>
        </form.InputGroup>

        <form.InputGroup as |inputGroup|>
          <inputGroup.Field
            @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
            @name="cached_input_cost"
            @title={{i18n "discourse_ai.llms.cost_cached_input"}}
            @tooltip={{i18n "discourse_ai.llms.hints.cost_cached_input"}}
            @type="input-number"
            as |field|
          >
            <field.Control lang="en" min="0" step="any" />
          </inputGroup.Field>

          <inputGroup.Field
            @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
            @name="cache_write_cost"
            @title={{i18n "discourse_ai.llms.cost_cache_write"}}
            @tooltip={{i18n "discourse_ai.llms.hints.cost_cache_write"}}
            @type="input-number"
            as |field|
          >
            <field.Control lang="en" min="0" step="any" />
          </inputGroup.Field>
        </form.InputGroup>

        <form.Field
          @format="large"
          @name="max_output_tokens"
          @title={{i18n "discourse_ai.llms.max_output_tokens"}}
          @tooltip={{i18n "discourse_ai.llms.hints.max_output_tokens"}}
          @type="input-number"
          as |field|
        >
          <field.Control lang="en" min="0" step="any" />
        </form.Field>

        <form.Field
          @format="large"
          @name="vision_mode"
          @onSet={{this.setVisionMode}}
          @title={{i18n "discourse_ai.llms.vision_mode"}}
          @tooltip={{i18n "discourse_ai.llms.vision_mode_help"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            <select.Option @value="disabled">
              {{i18n "discourse_ai.llms.vision_modes.disabled.title"}}
            </select.Option>
            <select.Option @value="delegated">
              {{i18n "discourse_ai.llms.vision_modes.delegated.title"}}
            </select.Option>
            <select.Option @value="native">
              {{i18n "discourse_ai.llms.vision_modes.native.title"}}
            </select.Option>
          </field.Control>
        </form.Field>

        {{#if (eq data.vision_mode "delegated")}}
          <form.Field
            @format="large"
            @name="vision_llm_model_id"
            @title={{i18n "discourse_ai.llms.vision_model"}}
            @tooltip={{i18n "discourse_ai.llms.vision_model_help"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <AiLlmSelector
                class="ai-llm-editor__vision-model-selector"
                @llms={{this.nativeVisionModels}}
                @onChange={{field.set}}
                @value={{field.value}}
              />
            </field.Control>
          </form.Field>
          {{#unless this.nativeVisionModels.length}}
            <form.Alert @icon="triangle-exclamation">
              {{i18n "discourse_ai.llms.no_native_vision_models"}}
            </form.Alert>
          {{/unless}}
        {{/if}}

        <form.Field
          @format="large"
          @name="allowed_attachment_types"
          @title={{i18n "discourse_ai.llms.allowed_attachment_types"}}
          @tooltip={{i18n "discourse_ai.llms.hints.allowed_attachment_types"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <AiLlmAttachmentTypes
              @onChange={{field.set}}
              @value={{field.value}}
            />
          </field.Control>
        </form.Field>

        {{#if @model.user}}
          <form.Container @title={{i18n "discourse_ai.llms.ai_bot_user"}}>
            <a
              class="avatar"
              data-user-card={{@model.user.username}}
              href={{@model.user.path}}
            >
              {{dBoundAvatarTemplate @model.user.avatar_template "small"}}
            </a>
            <LinkTo @model={{this.adminUser}} @route="adminUser">
              {{@model.user.username}}
            </LinkTo>
          </form.Container>
        {{/if}}
      {{/unless}}

      {{#if (gt data.llm_quotas.length 0)}}
        <form.Container
          @format="full"
          @title={{i18n "discourse_ai.llms.quotas.title"}}
        >
          <div class="ai-llm-quotas">
            <form.Collection
              @name="llm_quotas"
              as |collection index collectionData|
            >
              <div class="ai-llm-quotas__item">
                <div class="ai-llm-quotas__item-header">
                  <dl class="ai-llm-quotas__group">
                    <dt class="ai-llm-quotas__group-label">{{i18n
                        "discourse_ai.llms.quotas.group"
                      }}</dt>
                    <dd class="ai-llm-quotas__group-name">
                      <a
                        class="ai-llm-quotas__group-link"
                        href={{groupPath collectionData.group_name}}
                      >
                        {{dIcon "users"}}
                        <span>{{collectionData.group_name}}</span>
                      </a>
                    </dd>
                  </dl>

                  <form.Button
                    class="btn-danger ai-llm-quotas__delete-btn"
                    @action={{fn collection.remove index}}
                    @icon="trash-can"
                  />
                </div>

                <div class="ai-llm-quotas__limits">
                  <collection.Field
                    @name="max_tokens"
                    @title={{i18n "discourse_ai.llms.quotas.max_tokens"}}
                    @type="input-number"
                    as |field|
                  >
                    <field.Control
                      class="ai-llm-quotas__input ai-llm-quotas__input--tokens"
                      min="1"
                    />
                  </collection.Field>

                  <collection.Field
                    @name="max_usages"
                    @title={{i18n "discourse_ai.llms.quotas.max_usages"}}
                    @type="input-number"
                    as |field|
                  >
                    <field.Control
                      class="ai-llm-quotas__input ai-llm-quotas__input--usages"
                      min="1"
                    />
                  </collection.Field>

                  <collection.Field
                    @name="max_cost"
                    @title={{i18n "discourse_ai.llms.quotas.max_cost"}}
                    @type="input-number"
                    as |field|
                  >
                    <field.Control
                      class="ai-llm-quotas__input ai-llm-quotas__input--cost"
                      min="0.01"
                      step="0.01"
                    />
                  </collection.Field>

                  <collection.Field
                    @name="duration_seconds"
                    @title={{i18n "discourse_ai.llms.quotas.duration"}}
                    @type="custom"
                    @validation="required"
                    as |field|
                  >
                    <field.Control>
                      <DurationSelector
                        class="ai-llm-quotas__duration"
                        @onChange={{field.set}}
                        @value={{collectionData.duration_seconds}}
                      />
                    </field.Control>
                  </collection.Field>
                </div>
              </div>
            </form.Collection>
          </div>
        </form.Container>

        <form.Button
          class="ai-llm-editor__add-quota-btn"
          @action={{fn
            this.openAddQuotaModal
            (fn form.addItemToCollection "llm_quotas")
          }}
          @icon="plus"
          @label="discourse_ai.llms.quotas.add"
        />
      {{/if}}

      <form.Actions>
        <form.Submit />
        <form.Button
          class="btn-default"
          @action={{fn this.test data}}
          @disabled={{this.testRunning}}
          @label="discourse_ai.llms.tests.title"
        />

        {{#if (eq data.llm_quotas.length 0)}}
          <form.Button
            class="btn-default ai-llm-editor__add-quota-btn"
            @action={{fn
              this.openAddQuotaModal
              (fn form.addItemToCollection "llm_quotas")
            }}
            @label="discourse_ai.llms.quotas.add"
          />
        {{/if}}

        {{#unless @model.isNew}}
          {{#unless @model.seeded}}
            <form.Button
              class="btn-danger"
              @action={{this.delete}}
              @icon="trash-can"
              @label="discourse_ai.llms.delete"
            />
          {{/unless}}
        {{/unless}}
      </form.Actions>

      {{#if this.displayTestResult}}
        <form.Container @format="full">
          <DConditionalLoadingSpinner
            @condition={{this.testRunning}}
            @size="small"
          >
            {{#if this.testResult}}
              <div class="ai-llm-editor-tests__success">
                {{dIcon "check"}}
                {{i18n "discourse_ai.llms.tests.success"}}
              </div>
            {{else}}
              <div class="ai-llm-editor-tests__failure">
                {{dIcon "xmark"}}
                {{this.testErrorMessage}}
                <ul>
                  {{#each this.testValidationErrors as |error|}}
                    <li>{{error}}</li>
                  {{/each}}
                </ul>
              </div>
            {{/if}}
          </DConditionalLoadingSpinner>
        </form.Container>
      {{/if}}
    </Form>
  </template>
}
