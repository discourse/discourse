import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import Avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import DurationSelector from "./ai-quota-duration-selector";
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
        provider_params: this.computeProviderParams(info.provider),
        input_cost: modelInfo.input_cost,
        output_cost: modelInfo.output_cost,
        cached_input_cost: modelInfo.cached_input_cost,
      };
    }

    const { model } = this.args;

    return {
      max_prompt_tokens: model.max_prompt_tokens,
      max_output_tokens: model.max_output_tokens,
      api_key: model.api_key,
      tokenizer: model.tokenizer,
      url: model.url,
      display_name: model.display_name,
      name: model.name,
      provider: model.provider,
      enabled_chat_bot: model.enabled_chat_bot,
      vision_enabled: model.vision_enabled,
      input_cost: model.input_cost,
      output_cost: model.output_cost,
      cached_input_cost: model.cached_input_cost,
      provider_params: this.computeProviderParams(
        model.provider,
        model.provider_params
      ),
      llm_quotas: model.llm_quotas,
    };
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
    } else {
      return i18n("discourse_ai.llms.tests.failure", { error: this.testError });
    }
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
        persona: m.name,
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

  get showAddQuotaButton() {
    return !this.args.model.isNew;
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
    return provider !== "aws_bedrock";
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

    return Object.entries(params).reduce((acc, [field, value]) => {
      if (typeof value === "string") {
        acc[field] = { type: value };
      } else if (typeof value === "object") {
        if (value.values) {
          value = { ...value };
          value.values = value.values.map((v) => ({ id: v, name: v }));
        }

        acc[field] = {
          type: value.type || "text",
          values: value.values || [],
          default: value.default ?? undefined,
        };
      } else {
        acc[field] = { type: "text" }; // fallback
      }
      return acc;
    }, {});
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
        this.args.llms.addObject(this.args.model);
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
      const configTestResult = await this.args.model.testConfig(data);
      this.testResult = configTestResult.success;

      if (this.testResult) {
        this.testError = null;
        this.testValidationErrors = null;
      } else {
        this.testError = configTestResult.error;
        this.testValidationErrors = configTestResult.validation_errors;
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
            this.args.llms.removeObject(this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-llms.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  providerParamsKeys(providerParams) {
    return providerParams ? Object.keys(providerParams) : [];
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-llm-editor"
      as |form data|
    >
      {{#if this.modulesUsingModel}}
        <form.Alert @icon="circle-info">
          {{this.inUseWarning}}
        </form.Alert>
      {{/if}}

      <form.Field
        @name="display_name"
        @title={{i18n "discourse_ai.llms.display_name"}}
        @validation="required|length:1,100"
        @format="large"
        @tooltip={{i18n "discourse_ai.llms.hints.display_name"}}
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="name"
        @title={{i18n "discourse_ai.llms.name"}}
        @tooltip={{i18n "discourse_ai.llms.hints.name"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="provider"
        @title={{i18n "discourse_ai.llms.provider"}}
        @format="large"
        @validation="required"
        @onSet={{this.setProvider}}
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

      {{#if (this.canEditURL data.provider)}}
        <form.Field
          @name="url"
          @title={{i18n "discourse_ai.llms.url"}}
          @validation="required"
          @format="large"
          as |field|
        >
          <field.Input />
        </form.Field>
      {{/if}}

      <form.Field
        @name="api_key"
        @title={{i18n "discourse_ai.llms.api_key"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Password autocomplete="off" data-1p-ignore />
      </form.Field>

      <form.Object @name="provider_params" as |object providerParamsData|>
        {{#each (this.providerParamsKeys providerParamsData) as |name|}}
          {{#let
            (get (this.metaProviderParams data.provider) name)
            as |params|
          }}
            <object.Field
              @name={{name}}
              @title={{i18n (concat "discourse_ai.llms.provider_fields." name)}}
              @format="large"
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
          {{/let}}
        {{/each}}
      </form.Object>

      <form.Field
        @name="tokenizer"
        @title={{i18n "discourse_ai.llms.tokenizer"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Select as |select|>
          {{#each this.tokenizers as |tokenizer|}}
            <select.Option
              @value={{tokenizer.id}}
            >{{tokenizer.name}}</select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <form.Field
        @name="max_prompt_tokens"
        @title={{i18n "discourse_ai.llms.max_prompt_tokens"}}
        @tooltip={{i18n "discourse_ai.llms.hints.max_prompt_tokens"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Input @type="number" step="any" min="0" lang="en" />
      </form.Field>

      <form.InputGroup as |inputGroup|>
        <inputGroup.Field
          @name="input_cost"
          @title={{i18n "discourse_ai.llms.cost_input"}}
          @tooltip={{i18n "discourse_ai.llms.hints.cost_input"}}
          @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
          as |field|
        >
          <field.Input @type="number" step="any" min="0" lang="en" />
        </inputGroup.Field>

        <inputGroup.Field
          @name="cached_input_cost"
          @title={{i18n "discourse_ai.llms.cost_cached_input"}}
          @tooltip={{i18n "discourse_ai.llms.hints.cost_cached_input"}}
          @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
          as |field|
        >
          <field.Input @type="number" step="any" min="0" lang="en" />
        </inputGroup.Field>

        <inputGroup.Field
          @name="output_cost"
          @title={{i18n "discourse_ai.llms.cost_output"}}
          @tooltip={{i18n "discourse_ai.llms.hints.cost_output"}}
          @helpText={{i18n "discourse_ai.llms.hints.cost_measure"}}
          as |field|
        >
          <field.Input @type="number" step="any" min="0" lang="en" />
        </inputGroup.Field>
      </form.InputGroup>

      <form.Field
        @name="max_output_tokens"
        @title={{i18n "discourse_ai.llms.max_output_tokens"}}
        @tooltip={{i18n "discourse_ai.llms.hints.max_output_tokens"}}
        @format="large"
        as |field|
      >
        <field.Input @type="number" step="any" min="0" lang="en" />
      </form.Field>

      <form.Field
        @name="vision_enabled"
        @title={{i18n "discourse_ai.llms.vision_enabled"}}
        @tooltip={{i18n "discourse_ai.llms.hints.vision_enabled"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="enabled_chat_bot"
        @title={{i18n "discourse_ai.llms.enabled_chat_bot"}}
        @tooltip={{i18n "discourse_ai.llms.hints.enabled_chat_bot"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      {{#if @model.user}}
        <form.Container @title={{i18n "discourse_ai.llms.ai_bot_user"}}>
          <a
            class="avatar"
            href={{@model.user.path}}
            data-user-card={{@model.user.username}}
          >
            {{Avatar @model.user.avatar_template "small"}}
          </a>
          <LinkTo @route="adminUser" @model={{this.adminUser}}>
            {{@model.user.username}}
          </LinkTo>
        </form.Container>
      {{/if}}

      {{#if (gt data.llm_quotas.length 0)}}
        <form.Container @title={{i18n "discourse_ai.llms.quotas.title"}}>
          <table class="ai-llm-quotas__table">
            <thead class="ai-llm-quotas__table-head">
              <tr class="ai-llm-quotas__header-row">
                <th class="ai-llm-quotas__header">{{i18n
                    "discourse_ai.llms.quotas.group"
                  }}</th>
                <th class="ai-llm-quotas__header">{{i18n
                    "discourse_ai.llms.quotas.max_tokens"
                  }}</th>
                <th class="ai-llm-quotas__header">{{i18n
                    "discourse_ai.llms.quotas.max_usages"
                  }}</th>
                <th class="ai-llm-quotas__header">{{i18n
                    "discourse_ai.llms.quotas.duration"
                  }}</th>
                <th
                  class="ai-llm-quotas__header ai-llm-quotas__header--actions"
                ></th>
                <th></th>
              </tr>
            </thead>
            <tbody class="ai-llm-quotas__table-body">
              <form.Collection
                @name="llm_quotas"
                @tagName="tr"
                class="ai-llm-quotas__row"
                as |collection index collectionData|
              >
                <td
                  class="ai-llm-quotas__cell"
                >{{collectionData.group_name}}</td>
                <td class="ai-llm-quotas__cell">
                  <collection.Field
                    @name="max_tokens"
                    @title="max_tokens"
                    @showTitle={{false}}
                    as |field|
                  >
                    <field.Input
                      @type="number"
                      class="ai-llm-quotas__input"
                      min="1"
                    />
                  </collection.Field>
                </td>
                <td class="ai-llm-quotas__cell">
                  <collection.Field
                    @name="max_usages"
                    @title="max_usages"
                    @showTitle={{false}}
                    as |field|
                  >
                    <field.Input
                      @type="number"
                      class="ai-llm-quotas__input"
                      min="1"
                    />
                  </collection.Field>
                </td>
                <td class="ai-llm-quotas__cell">
                  <collection.Field
                    @name="duration_seconds"
                    @title="duration_seconds"
                    @showTitle={{false}}
                    as |field|
                  >
                    <field.Custom>
                      <DurationSelector
                        @value={{collectionData.duration_seconds}}
                        @onChange={{field.set}}
                      />
                    </field.Custom>
                  </collection.Field>
                </td>
                <td>
                  <form.Button
                    @icon="trash-can"
                    @action={{fn collection.remove index}}
                    class="btn-danger ai-llm-quotas__delete-btn"
                  />
                </td>
              </form.Collection>
            </tbody>
          </table>
        </form.Container>

        <form.Button
          @action={{fn
            this.openAddQuotaModal
            (fn form.addItemToCollection "llm_quotas")
          }}
          @icon="plus"
          @label="discourse_ai.llms.quotas.add"
          class="ai-llm-editor__add-quota-btn"
        />
      {{/if}}

      <form.Actions>
        <form.Button
          @action={{fn this.test data}}
          @disabled={{this.testRunning}}
          @label="discourse_ai.llms.tests.title"
        />

        <form.Submit />

        {{#if (eq data.llm_quotas.length 0)}}
          <form.Button
            @action={{fn
              this.openAddQuotaModal
              (fn form.addItemToCollection "llm_quotas")
            }}
            @label="discourse_ai.llms.quotas.add"
            class="ai-llm-editor__add-quota-btn"
          />
        {{/if}}

        {{#unless @model.isNew}}
          <form.Button
            @action={{this.delete}}
            @label="discourse_ai.llms.delete"
            class="btn-danger"
          />
        {{/unless}}
      </form.Actions>

      {{#if this.displayTestResult}}
        <form.Container @format="full">
          <ConditionalLoadingSpinner
            @size="small"
            @condition={{this.testRunning}}
          >
            {{#if this.testResult}}
              <div class="ai-llm-editor-tests__success">
                {{icon "check"}}
                {{i18n "discourse_ai.llms.tests.success"}}
              </div>
            {{else}}
              <div class="ai-llm-editor-tests__failure">
                {{icon "xmark"}}
                {{this.testErrorMessage}}
                <ul>
                  {{#each this.testValidationErrors as |error|}}
                    <li>{{error}}</li>
                  {{/each}}
                </ul>
              </div>
            {{/if}}
          </ConditionalLoadingSpinner>
        </form.Container>
      {{/if}}
    </Form>
  </template>
}
