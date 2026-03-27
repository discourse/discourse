import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { and, eq, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiSecretSelector from "./ai-secret-selector";

export default class AiMcpServerEditorForm extends Component {
  @service dialog;
  @service router;
  @service toasts;

  @tracked isSaving = false;
  @tracked isTesting = false;
  @tracked isConnecting = false;
  @tracked isDisconnecting = false;
  @tracked testResult = null;
  @tracked formData = {};
  @tracked showOauthDetails = false;
  @tracked showOauthAdvancedOptions = false;

  constructor() {
    super(...arguments);
    this.formData = this.buildFormData();
    this.showOauthAdvancedOptions = this.hasOauthAdvancedOptions(this.formData);
  }

  buildFormData() {
    const { model } = this.args;

    return {
      name: model.name || "",
      description: model.description || "",
      url: model.url || "",
      auth_type:
        model.auth_type || (model.ai_secret_id ? "header_secret" : "none"),
      ai_secret_id: model.ai_secret_id || null,
      auth_header: model.auth_header || "Authorization",
      auth_scheme: model.auth_scheme ?? "Bearer",
      oauth_client_registration:
        model.oauth_client_registration || "client_metadata_document",
      oauth_client_id: model.oauth_client_id || "",
      oauth_client_secret_ai_secret_id:
        model.oauth_client_secret_ai_secret_id || null,
      oauth_scopes: model.oauth_scopes || "",
      oauth_authorization_params: this.formatOauthParams(
        model.oauth_authorization_params
      ),
      oauth_token_params: this.formatOauthParams(model.oauth_token_params),
      oauth_require_refresh_token: model.oauth_require_refresh_token ?? false,
      enabled: model.enabled ?? true,
      timeout_seconds: model.timeout_seconds || 30,
    };
  }

  formatOauthParams(value) {
    if (!value || Object.keys(value).length === 0) {
      return "";
    }

    return JSON.stringify(value, null, 2);
  }

  hasOauthAdvancedOptions(data) {
    return (
      !!data.oauth_authorization_params ||
      !!data.oauth_token_params ||
      !!data.oauth_require_refresh_token
    );
  }

  parseOauthParams(value, fieldKey) {
    const trimmedValue = value?.trim();

    if (!trimmedValue) {
      return {};
    }

    let parsedValue;

    try {
      parsedValue = JSON.parse(trimmedValue);
    } catch {
      throw new Error(
        i18n("discourse_ai.mcp_servers.oauth_json_object_required", {
          field: i18n(fieldKey),
        })
      );
    }

    if (
      !parsedValue ||
      Array.isArray(parsedValue) ||
      typeof parsedValue !== "object"
    ) {
      throw new Error(
        i18n("discourse_ai.mcp_servers.oauth_json_object_required", {
          field: i18n(fieldKey),
        })
      );
    }

    return parsedValue;
  }

  handleError(error) {
    if (error?.jqXHR || error?.responseJSON) {
      popupAjaxError(error);
      return;
    }

    this.dialog.alert({
      message: error?.message || String(error),
    });
  }

  get authTypes() {
    return [
      {
        id: "none",
        name: i18n("discourse_ai.mcp_servers.auth_types.none"),
      },
      {
        id: "header_secret",
        name: i18n("discourse_ai.mcp_servers.auth_types.header_secret"),
      },
      {
        id: "oauth",
        name: i18n("discourse_ai.mcp_servers.auth_types.oauth"),
      },
    ];
  }

  get oauthClientRegistrations() {
    return [
      {
        id: "client_metadata_document",
        name: i18n(
          "discourse_ai.mcp_servers.oauth_client_registration_types.client_metadata_document"
        ),
      },
      {
        id: "manual",
        name: i18n(
          "discourse_ai.mcp_servers.oauth_client_registration_types.manual"
        ),
      },
    ];
  }

  get oauthStatusLabelKey() {
    return `discourse_ai.mcp_servers.oauth_statuses.${
      this.args.model.oauth_status || "disconnected"
    }`;
  }

  get oauthConnectLabelKey() {
    return this.canDisconnectOAuth
      ? "discourse_ai.mcp_servers.oauth_reconnect"
      : "discourse_ai.mcp_servers.oauth_connect";
  }

  get canDisconnectOAuth() {
    const status = this.args.model.oauth_status;
    return status === "connected" || status === "refresh_failed";
  }

  get canTestOAuthConnection() {
    return this.args.model.oauth_status === "connected";
  }

  @action
  resetTestResult(value, { name, set }) {
    set(name, value);
    this.testResult = null;
  }

  @action
  normalizeData(data) {
    const payload = { ...data };

    payload.auth_type ||= payload.ai_secret_id ? "header_secret" : "none";
    payload.ai_secret_id ||= null;
    payload.oauth_client_secret_ai_secret_id ||= null;
    payload.oauth_client_id = payload.oauth_client_id?.trim() || null;
    payload.oauth_scopes = payload.oauth_scopes?.trim() || null;
    payload.auth_header = payload.auth_header?.trim() || "Authorization";
    payload.auth_scheme = payload.auth_scheme?.trim() ?? "Bearer";

    if (payload.auth_type !== "header_secret") {
      payload.ai_secret_id = null;
    }

    if (payload.auth_type !== "oauth") {
      payload.oauth_client_registration = "client_metadata_document";
      payload.oauth_client_id = null;
      payload.oauth_client_secret_ai_secret_id = null;
      payload.oauth_scopes = null;
      payload.oauth_authorization_params = {};
      payload.oauth_token_params = {};
      payload.oauth_require_refresh_token = false;
    } else {
      payload.oauth_client_registration ||= "client_metadata_document";
      payload.oauth_authorization_params = this.parseOauthParams(
        payload.oauth_authorization_params,
        "discourse_ai.mcp_servers.oauth_authorization_params"
      );
      payload.oauth_token_params = this.parseOauthParams(
        payload.oauth_token_params,
        "discourse_ai.mcp_servers.oauth_token_params"
      );
      payload.oauth_require_refresh_token =
        !!payload.oauth_require_refresh_token;

      if (payload.oauth_client_registration !== "manual") {
        payload.oauth_client_id = null;
        payload.oauth_client_secret_ai_secret_id = null;
      }
    }

    return payload;
  }

  async persist(data, { transition = true, toast = true } = {}) {
    const isNew = this.args.model.isNew;

    await this.args.model.save(this.normalizeData(data));

    if (isNew) {
      this.args.mcpServers.content.push(this.args.model);
    }

    if (transition) {
      await this.router.replaceWith(
        "adminPlugins.show.discourse-ai-tools.mcp-server-edit",
        this.args.model
      );
    }

    if (toast) {
      this.toasts.success({
        data: { message: i18n("discourse_ai.mcp_servers.saved") },
        duration: "short",
      });
    }
  }

  @action
  async save(data) {
    this.isSaving = true;

    try {
      await this.persist(data);
    } catch (e) {
      this.handleError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  @action
  async testConnection(data) {
    this.isTesting = true;
    this.testResult = null;

    try {
      this.testResult = await this.args.model.testConnection(
        this.normalizeData(data)
      );
    } catch (e) {
      this.handleError(e);
    } finally {
      this.isTesting = false;
    }
  }

  @action
  async startOAuth(data) {
    this.isConnecting = true;

    try {
      await this.persist(data, { transition: false, toast: false });
      window.location.assign(this.args.model.oauthStartPath);
    } catch (e) {
      this.handleError(e);
      this.isConnecting = false;
    }
  }

  @action
  async disconnectOAuth() {
    this.isDisconnecting = true;

    try {
      await this.args.model.disconnectOAuth();
      this.testResult = null;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isDisconnecting = false;
    }
  }

  @action
  toggleOauthDetails() {
    this.showOauthDetails = !this.showOauthDetails;
  }

  @action
  toggleOauthAdvancedOptions() {
    this.showOauthAdvancedOptions = !this.showOauthAdvancedOptions;
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.mcp_servers.confirm_delete"),
      didConfirm: async () => {
        await this.args.model.destroyRecord();
        removeValueFromArray(this.args.mcpServers.content, this.args.model);
        this.router.transitionTo("adminPlugins.show.discourse-ai-tools.index");
      },
    });
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-tool-editor ai-mcp-server-editor"
      as |form data|
    >
      <form.Field
        @name="name"
        @title={{i18n "discourse_ai.mcp_servers.name"}}
        @validation="required|length:1,100"
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="description"
        @title={{i18n "discourse_ai.mcp_servers.description"}}
        @validation="required|length:1,1000"
        @format="large"
        @type="textarea"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="url"
        @title={{i18n "discourse_ai.mcp_servers.url"}}
        @validation="required|length:1,1000"
        @onSet={{this.resetTestResult}}
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="auth_type"
        @title={{i18n "discourse_ai.mcp_servers.auth_type"}}
        @onSet={{this.resetTestResult}}
        @format="large"
        @type="select"
        as |field|
      >
        <field.Control @includeNone={{false}} as |select|>
          {{#each this.authTypes as |authType|}}
            <select.Option @value={{authType.id}}>
              {{authType.name}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      {{#if (eq data.auth_type "header_secret")}}
        <form.Field
          @name="ai_secret_id"
          @title={{i18n "discourse_ai.mcp_servers.secret"}}
          @format="large"
          @type="custom"
          as |field|
        >
          <field.Control>
            <AiSecretSelector
              @value={{field.value}}
              @secrets={{@secrets}}
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="auth_header"
          @title={{i18n "discourse_ai.mcp_servers.auth_header"}}
          @validation="required|length:1,100"
          @format="large"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="auth_scheme"
          @title={{i18n "discourse_ai.mcp_servers.auth_scheme"}}
          @format="large"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>
      {{/if}}

      {{#if (eq data.auth_type "oauth")}}
        <form.Field
          @name="oauth_client_registration"
          @title={{i18n "discourse_ai.mcp_servers.oauth_client_registration"}}
          @onSet={{this.resetTestResult}}
          @format="large"
          @type="select"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            {{#each this.oauthClientRegistrations as |registration|}}
              <select.Option @value={{registration.id}}>
                {{registration.name}}
              </select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        {{#if (eq data.oauth_client_registration "manual")}}
          <form.Field
            @name="oauth_client_id"
            @title={{i18n "discourse_ai.mcp_servers.oauth_client_id"}}
            @validation="required|length:1,1000"
            @format="large"
            @type="input"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @name="oauth_client_secret_ai_secret_id"
            @title={{i18n "discourse_ai.mcp_servers.oauth_client_secret"}}
            @format="large"
            @type="custom"
            as |field|
          >
            <field.Control>
              <AiSecretSelector
                @value={{field.value}}
                @secrets={{@secrets}}
                @onChange={{field.set}}
              />
            </field.Control>
          </form.Field>
        {{/if}}

        <form.Field
          @name="oauth_scopes"
          @title={{i18n "discourse_ai.mcp_servers.oauth_scopes"}}
          @format="large"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Button
          @action={{this.toggleOauthAdvancedOptions}}
          @label={{if
            this.showOauthAdvancedOptions
            "discourse_ai.mcp_servers.oauth_hide_advanced_options"
            "discourse_ai.mcp_servers.oauth_show_advanced_options"
          }}
          class="btn-flat btn-small ai-mcp-server-editor__oauth-details-toggle"
        />

        {{#if this.showOauthAdvancedOptions}}
          <form.Field
            @name="oauth_authorization_params"
            @title={{i18n
              "discourse_ai.mcp_servers.oauth_authorization_params"
            }}
            @tooltip={{i18n
              "discourse_ai.mcp_servers.oauth_authorization_params_help"
            }}
            @format="full"
            @type="textarea"
            as |field|
          >
            <field.Control
              @height={{100}}
              placeholder={{i18n
                "discourse_ai.mcp_servers.oauth_authorization_params_placeholder"
              }}
            />
          </form.Field>

          <form.Field
            @name="oauth_token_params"
            @title={{i18n "discourse_ai.mcp_servers.oauth_token_params"}}
            @tooltip={{i18n "discourse_ai.mcp_servers.oauth_token_params_help"}}
            @format="full"
            @type="textarea"
            as |field|
          >
            <field.Control
              @height={{100}}
              placeholder={{i18n
                "discourse_ai.mcp_servers.oauth_token_params_placeholder"
              }}
            />
          </form.Field>

          <form.Field
            @name="oauth_require_refresh_token"
            @title={{i18n
              "discourse_ai.mcp_servers.oauth_require_refresh_token"
            }}
            @tooltip={{i18n
              "discourse_ai.mcp_servers.oauth_require_refresh_token_help"
            }}
            @format="full"
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        {{#unless @model.isNew}}
          <div class="ai-mcp-server-editor__oauth-state">
            <h3>{{i18n "discourse_ai.mcp_servers.oauth_connection"}}</h3>

            <div class="ai-mcp-server-editor__oauth-row">
              <span class="ai-mcp-server-editor__oauth-label">
                {{i18n "discourse_ai.mcp_servers.oauth_status"}}
              </span>
              <span
                class="ai-tool-list__credential-badge
                  {{if
                    (eq @model.oauth_status 'connected')
                    'ai-tool-list__credential-badge--bound'
                    'ai-tool-list__credential-badge--missing'
                  }}"
              >
                {{i18n this.oauthStatusLabelKey}}
              </span>
            </div>

            {{#if @model.oauth_last_error}}
              <div class="ai-mcp-server-editor__oauth-row">
                <span class="ai-mcp-server-editor__oauth-label">
                  {{i18n "discourse_ai.mcp_servers.oauth_last_error"}}
                </span>
                <span class="ai-mcp-server-editor__oauth-value">
                  {{@model.oauth_last_error}}
                </span>
              </div>
            {{/if}}

            {{#if this.showOauthDetails}}
              {{#if @model.oauth_client_metadata_url}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n
                      "discourse_ai.mcp_servers.oauth_client_metadata_url"
                    }}
                  </span>
                  <code class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_client_metadata_url}}
                  </code>
                </div>
              {{/if}}

              {{#if @model.oauth_granted_scopes}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n "discourse_ai.mcp_servers.oauth_granted_scopes"}}
                  </span>
                  <span class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_granted_scopes}}
                  </span>
                </div>
              {{/if}}

              {{#if @model.oauth_access_token_expires_at}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n
                      "discourse_ai.mcp_servers.oauth_access_token_expires_at"
                    }}
                  </span>
                  <span class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_access_token_expires_at}}
                  </span>
                </div>
              {{/if}}

              {{#if @model.oauth_issuer}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n "discourse_ai.mcp_servers.oauth_issuer"}}
                  </span>
                  <span class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_issuer}}
                  </span>
                </div>
              {{/if}}

              {{#if @model.oauth_authorization_endpoint}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n
                      "discourse_ai.mcp_servers.oauth_authorization_endpoint"
                    }}
                  </span>
                  <code class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_authorization_endpoint}}
                  </code>
                </div>
              {{/if}}

              {{#if @model.oauth_token_endpoint}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n "discourse_ai.mcp_servers.oauth_token_endpoint"}}
                  </span>
                  <code class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_token_endpoint}}
                  </code>
                </div>
              {{/if}}

              {{#if @model.oauth_revocation_endpoint}}
                <div class="ai-mcp-server-editor__oauth-row">
                  <span class="ai-mcp-server-editor__oauth-label">
                    {{i18n
                      "discourse_ai.mcp_servers.oauth_revocation_endpoint"
                    }}
                  </span>
                  <code class="ai-mcp-server-editor__oauth-value">
                    {{@model.oauth_revocation_endpoint}}
                  </code>
                </div>
              {{/if}}
            {{/if}}

            <form.Button
              @action={{this.toggleOauthDetails}}
              @label={{if
                this.showOauthDetails
                "discourse_ai.mcp_servers.oauth_hide_details"
                "discourse_ai.mcp_servers.oauth_show_details"
              }}
              class="btn-flat btn-small ai-mcp-server-editor__oauth-details-toggle"
            />
          </div>
        {{/unless}}
      {{/if}}

      <form.Field
        @name="timeout_seconds"
        @title={{i18n "discourse_ai.mcp_servers.timeout_seconds"}}
        @tooltip={{i18n "discourse_ai.mcp_servers.timeout_seconds_tooltip"}}
        @validation="required|number"
        @format="large"
        @type="input-number"
        as |field|
      >
        <field.Control @min={{1}} @max={{300}} lang="en" />
      </form.Field>

      <form.Field
        @name="enabled"
        @title={{i18n "discourse_ai.mcp_servers.enabled"}}
        @showTitle={{false}}
        @format="large"
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </form.Field>

      {{#if this.testResult}}
        <div class="ai-mcp-server-editor__test-result">
          <h3>{{i18n "discourse_ai.mcp_servers.test_result"}}</h3>
          <p>
            {{i18n
              "discourse_ai.mcp_servers.test_summary"
              count=this.testResult.tool_count
              version=this.testResult.protocol_version
            }}
          </p>
          {{#if this.testResult.tool_names.length}}
            <ul>
              {{#each this.testResult.tool_names as |toolName|}}
                <li>{{toolName}}</li>
              {{/each}}
            </ul>
          {{/if}}
        </div>
      {{/if}}

      <form.Actions>
        <form.Submit />

        {{#unless @model.isNew}}
          {{#if (eq data.auth_type "oauth")}}
            <form.Button
              @action={{fn this.startOAuth data}}
              @label={{this.oauthConnectLabelKey}}
              @isLoading={{this.isConnecting}}
              @disabled={{this.isDisconnecting}}
              class="btn-default"
            />

            {{#if this.canDisconnectOAuth}}
              <form.Button
                @action={{this.disconnectOAuth}}
                @label="discourse_ai.mcp_servers.oauth_disconnect"
                @isLoading={{this.isDisconnecting}}
                @disabled={{this.isConnecting}}
                class="btn-default"
              />
            {{/if}}
          {{/if}}

          <form.Button
            @action={{fn this.testConnection data}}
            @label="discourse_ai.mcp_servers.test"
            @isLoading={{this.isTesting}}
            @disabled={{and
              (eq data.auth_type "oauth")
              (not this.canTestOAuthConnection)
            }}
            class="btn-default"
          />

          <form.Button
            @action={{this.delete}}
            @label="discourse_ai.mcp_servers.delete"
            class="btn-danger"
          />
        {{/unless}}
      </form.Actions>
    </Form>
  </template>
}
