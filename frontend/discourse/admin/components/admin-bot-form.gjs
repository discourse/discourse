import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ApiKeyScopeFields from "discourse/admin/components/api-key-scope-fields";
import GeneratedApiKey from "discourse/admin/components/generated-api-key";
import {
  buildScopesFormData,
  scopesPayload,
  selectedScopes,
  validateGranularScopes,
} from "discourse/admin/lib/api-key-scopes";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { withoutPrefix } from "discourse/lib/get-url";
import DiscourseURL, { applyQueryParams } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class AdminBotForm extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @service toasts;

  @tracked generatedApiKey;
  @tracked createdKeyData;

  #formApi;
  // Suggestions only replace a username the admin hasn't typed themselves.
  #suggestedUsername = "";

  @cached
  get formData() {
    return {
      name: "",
      username: "",
      trust_level: this.args.defaultTrustLevel,
      generate_api_key: false,
      scope_mode: "global",
      scopes: buildScopesFormData(this.args.apiKeyScopes.scopes),
    };
  }

  get usernameValidation() {
    return `required|length:${this.siteSettings.min_username_length},${this.siteSettings.max_username_length}`;
  }

  get #usernameIsSuggested() {
    return (this.#formApi.get("username") ?? "") === this.#suggestedUsername;
  }

  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  @action
  async updateName(name, { set }) {
    await set("name", name);

    if (this.#usernameIsSuggested) {
      discourseDebounce(this, this.#suggestUsername, name, 300);
    }
  }

  @action
  validate(data, helpers) {
    helpers.removeError("base");

    if (data.generate_api_key) {
      validateGranularScopes(data, helpers);
    } else {
      helpers.removeError("scopes");
    }
  }

  @action
  async createBot(data) {
    const payload = {
      bot: {
        name: data.name,
        username: data.username,
        trust_level: Number(data.trust_level),
      },
    };

    if (data.generate_api_key) {
      payload.key = { scope_mode: data.scope_mode };

      const scopes = scopesPayload(
        data.scope_mode,
        data.scopes,
        this.args.apiKeyScopes.globalScopes
      );
      if (scopes) {
        payload.key.scopes = scopes;
      }
    }

    let result;
    try {
      result = await ajax("/admin/users/bots.json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify(payload),
      });
    } catch (error) {
      this.#formApi.addError("base", {
        title: i18n("admin.users.bots.create"),
        message: extractError(error),
      });
      return;
    }

    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("admin.users.bots.created", {
          username: result.user.username,
        }),
      },
    });

    if (result.key) {
      this.generatedApiKey = result.key.key;
      this.createdKeyData = {
        description: result.key.description,
        scopeMode: data.scope_mode,
        scopes:
          data.scope_mode === "granular" ? selectedScopes(data.scopes) : null,
      };
    } else {
      await this.showBots();
    }
  }

  @action
  async showBots() {
    const botsUrl = applyQueryParams(
      this.router.urlFor("adminUsersList.show", "bots"),
      {
        filter: null,
        username: null,
        order: "created",
        asc: null,
        account_type: null,
        activation: null,
      }
    );
    await this.router.transitionTo(withoutPrefix(botsUrl));
    // The list manages sorting outside Ember's query-param registry.
    DiscourseURL.replaceState(botsUrl);
  }

  async #suggestUsername(name) {
    let username = "";
    if (name?.trim()) {
      try {
        ({ username } = await ajax(
          "/admin/users/bots/username_suggestion.json",
          {
            data: { name },
          }
        ));
      } catch {
        return;
      }
    }

    if (
      this.isDestroying ||
      this.#formApi.get("name") !== name ||
      !this.#usernameIsSuggested
    ) {
      return;
    }

    this.#suggestedUsername = username ?? "";
    await this.#formApi.set("username", this.#suggestedUsername);
  }

  <template>
    {{#if this.generatedApiKey}}
      <GeneratedApiKey
        @apiKey={{this.generatedApiKey}}
        @details={{this.createdKeyData}}
      >
        <DButton
          class="btn-default admin-bot-form__back"
          @action={{this.showBots}}
          @label="admin.users.bots.back"
        />
      </GeneratedApiKey>
    {{else}}
      <Form
        class="admin-bot-form"
        ...attributes
        @data={{this.formData}}
        @onRegisterApi={{this.registerFormApi}}
        @onSubmit={{this.createBot}}
        @validate={{this.validate}}
        as |form transientData|
      >
        <form.Field
          @format="large"
          @name="name"
          @onSet={{this.updateName}}
          @title={{i18n "admin.users.bots.name"}}
          @type="input"
          @validation={{if @nameRequired "required"}}
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @format="large"
          @name="username"
          @title={{i18n "admin.users.bots.username"}}
          @type="input"
          @validation={{this.usernameValidation}}
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @format="large"
          @name="trust_level"
          @title={{i18n "admin.users.bots.trust_level"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |control|>
            {{#each this.site.trustLevels as |trustLevel|}}
              <control.Option @value={{trustLevel.id}}>
                {{trustLevel.detailedName}}
              </control.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        <form.Field
          @description={{i18n "admin.users.bots.generate_api_key_description"}}
          @format="large"
          @name="generate_api_key"
          @title={{i18n "admin.users.bots.generate_api_key"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>

        {{#if transientData.generate_api_key}}
          <ApiKeyScopeFields
            @form={{form}}
            @scopeModeDescription={{i18n
              "admin.users.bots.scope_mode_description"
            }}
            @transientData={{transientData}}
          />
        {{/if}}

        <form.Actions>
          <form.Submit @label="admin.users.bots.create" />
          <form.Button
            class="btn-default admin-bot-form__cancel"
            @label="cancel"
            @route="adminUsersList.show"
            @routeModels="bots"
          />
        </form.Actions>
      </Form>
    {{/if}}
  </template>
}
