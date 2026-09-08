import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ApiKeyUrlsModal from "discourse/admin/components/modal/api-key-urls";
import { API_KEY_SCOPE_MODES } from "discourse/admin/lib/constants";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { clipboardCopy } from "discourse/lib/utilities";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasApiKeysNew extends Component {
  @service modal;
  @service store;
  @service toasts;

  @tracked username;
  @tracked loadingScopes = false;
  @tracked scopes = null;

  @tracked generatedApiKey = null;
  @tracked createdKeyData = null;

  userModes = [
    { id: "all", name: i18n("admin.api.all_users") },
    { id: "single", name: i18n("admin.api.single_user") },
  ];

  scopeModes = API_KEY_SCOPE_MODES.map((scopeMode) => {
    return { id: scopeMode, name: i18n(`admin.api.scopes.${scopeMode}`) };
  });

  globalScopes = null;

  constructor() {
    super(...arguments);
    this.#loadScopes();
  }

  @cached
  get formData() {
    let scopes = Object.keys(this.scopes).reduce((result, resource) => {
      result[resource] = this.scopes[resource].map((scope) => {
        const params = scope.params
          ? scope.params.reduce((acc, param) => {
              acc[param] = undefined;
              return acc;
            }, {})
          : {};

        return {
          key: scope.key,
          enabled: undefined,
          urls: scope.urls,
          ...(params && { params }),
        };
      });
      return result;
    }, {});

    return {
      user_mode: "all",
      scope_mode: "global",
      scopes,
    };
  }

  get scopeModeLabel() {
    return i18n(`admin.api.scopes.${this.createdKeyData.scopeMode}`);
  }

  @action
  updateUsername(field, selected) {
    this.username = selected[0];
    field.set(this.username);
  }

  @action
  async save(data) {
    const payload = {
      description: data.description,
      scope_mode: data.scope_mode,
    };

    if (data.user_mode === "single") {
      payload.username = data.user;
    }

    if (data.scope_mode === "granular") {
      payload.scopes = this.#selectedScopes(data.scopes);
    } else if (data.scope_mode === "read_only") {
      payload.scopes = this.globalScopes.filter(
        (scope) => scope.key === "read"
      );
    }

    try {
      const result = await this.store.createRecord("api-key").save(payload);
      this.generatedApiKey = result.payload.key;
      this.createdKeyData = {
        description: data.description,
        scopeMode: data.scope_mode,
        scopes:
          data.scope_mode === "granular"
            ? this.#selectedScopes(data.scopes)
            : null,
      };
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async copyApiKey() {
    await clipboardCopy(this.generatedApiKey);
    this.toasts.success({
      data: { message: i18n("admin.api_keys.key_copied_to_clipboard") },
      duration: "short",
    });
  }

  @bind
  atLeastOneGranularScope(data, { addError, removeError }) {
    removeError("scopes");

    if (
      data.scope_mode === "granular" &&
      this.#selectedScopes(data.scopes).length === 0
    ) {
      addError("scopes", {
        title: i18n("admin.api.scopes.title"),
        message: i18n("admin.api.scopes.one_or_more"),
      });
    }
  }

  @action
  async showURLs(urls) {
    await this.modal.show(ApiKeyUrlsModal, {
      model: { urls },
    });
  }

  @action
  paramsObjectKeys(paramsObjectData) {
    return Object.keys(paramsObjectData);
  }

  @action
  scopesDataKeys(scopesData) {
    return Object.keys(scopesData).sort();
  }

  #selectedScopes(scopes) {
    const enabledScopes = [];

    for (const [resource, resourceScopes] of Object.entries(scopes)) {
      enabledScopes.push(
        resourceScopes
          .filter((s) => s.enabled)
          .map((s) => {
            return {
              scope_id: `${resource}:${s.key}`,
              key: s.key,
              name: s.key,
              params: Object.keys(s.params),
              ...s.params,
            };
          })
      );
    }

    return enabledScopes.flat();
  }

  async #loadScopes() {
    try {
      this.loadingScopes = true;
      const data = await ajax("/admin/api/keys/scopes.json");

      this.globalScopes = data.scopes.global;
      delete data.scopes.global;

      this.scopes = data.scopes;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingScopes = false;
    }
  }

  <template>
    <BackButton @label="admin.api_keys.back" @route="adminApiKeys.index" />

    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <div class="admin-config-area-card">
          {{#if this.generatedApiKey}}
            <div class="generated-api-key-container">
              <div class="alert alert-warning">
                {{dIcon "triangle-exclamation"}}
                <span>{{i18n "admin.api.not_shown_again"}}</span>
              </div>

              {{#if this.createdKeyData}}
                <div class="generated-api-key__details">
                  {{#if this.createdKeyData.description}}
                    <div class="generated-api-key__detail-row">
                      <span class="generated-api-key__label">{{i18n
                          "admin.api.description"
                        }}</span>
                      <span>{{this.createdKeyData.description}}</span>
                    </div>
                  {{/if}}
                  <div class="generated-api-key__detail-row">
                    <span class="generated-api-key__label">{{i18n
                        "admin.api.scope_mode"
                      }}</span>
                    <span>{{this.scopeModeLabel}}</span>
                  </div>
                  {{#if this.createdKeyData.scopes}}
                    <div class="generated-api-key__detail-row">
                      <span class="generated-api-key__label">{{i18n
                          "admin.api.scopes.title"
                        }}</span>
                      <span class="generated-api-key__scope-badges">
                        {{#each this.createdKeyData.scopes as |scope|}}
                          <span class="generated-api-key__scope-badge">
                            {{scope.scope_id}}
                            {{#each scope.params as |paramName|}}
                              {{#if (get scope paramName)}}
                                <span
                                  class="generated-api-key__scope-param"
                                >({{paramName}}: {{get scope paramName}})</span>
                              {{/if}}
                            {{/each}}
                          </span>
                        {{/each}}
                      </span>
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              <div class="generated-api-key__key-row">
                <code class="generated-api-key">{{this.generatedApiKey}}</code>
                <DButton
                  class="btn-default generated-api-key__copy-btn"
                  @action={{this.copyApiKey}}
                  @icon="copy"
                  @label="admin.api_keys.copy_key"
                />
              </div>

              <DButton
                class="continue btn-default"
                @label="admin.api_keys.continue"
                @route="adminApiKeys.index"
              />
            </div>
          {{else}}
            <DConditionalLoadingSection @isLoading={{this.loadingScopes}}>
              <Form
                @data={{this.formData}}
                @onSubmit={{this.save}}
                @validate={{this.atLeastOneGranularScope}}
                as |form transientData|
              >
                <form.Field
                  @format="large"
                  @name="description"
                  @title={{i18n "admin.api.description"}}
                  @type="input"
                  @validation="required"
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @format="large"
                  @name="user_mode"
                  @title={{i18n "admin.api.user_mode"}}
                  @type="select"
                  @validation="required"
                  as |field|
                >
                  <field.Control as |select|>
                    {{#each this.userModes as |userMode|}}
                      <select.Option
                        @value={{userMode.id}}
                      >{{userMode.name}}</select.Option>
                    {{/each}}
                  </field.Control>
                </form.Field>

                {{#if (eq transientData.user_mode "single")}}
                  <form.Field
                    @format="large"
                    @name="user"
                    @title={{i18n "admin.api.user"}}
                    @type="custom"
                    @validation="required"
                    as |field|
                  >
                    <field.Control>
                      <EmailGroupUserChooser
                        @onChange={{fn this.updateUsername field}}
                        @options={{hash
                          maximum=1
                          filterPlaceholder="admin.api.user_placeholder"
                        }}
                        @value={{this.username}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                <form.Field
                  @format="large"
                  @name="scope_mode"
                  @title={{i18n "admin.api.scope_mode"}}
                  @type="select"
                  @validation="required"
                  as |field|
                >
                  <field.Control as |select|>
                    {{#each this.scopeModes as |scopeMode|}}
                      <select.Option
                        @value={{scopeMode.id}}
                      >{{scopeMode.name}}</select.Option>
                    {{/each}}
                  </field.Control>
                </form.Field>

                {{#if (eq transientData.scope_mode "granular")}}
                  <h2 class="scopes-title">{{i18n
                      "admin.api.scopes.title"
                    }}</h2>
                  <p>{{i18n "admin.api.scopes.description"}}</p>
                  <table class="scopes-table grid">
                    <thead>
                      <tr>
                        <td></td>
                        <td>{{i18n "admin.api.scopes.allowed_urls"}}</td>
                        <td>{{i18n
                            "admin.api.scopes.optional_allowed_parameters"
                          }}</td>
                      </tr>
                    </thead>
                    <tbody>
                      <form.Object
                        class="scopes-table__object"
                        @name="scopes"
                        as |scopesObject scopesData|
                      >
                        {{#each (this.scopesDataKeys scopesData) as |scopeKey|}}
                          <tr class="scope-resource-name">
                            <td><b>{{scopeKey}}</b></td>
                            <td></td>
                            <td></td>
                            <td></td>
                          </tr>

                          <scopesObject.Collection
                            @name={{scopeKey}}
                            @tagName="div"
                            as |topicsCollection index collectionData|
                          >
                            <tr>
                              <td>
                                <topicsCollection.Field
                                  @name="enabled"
                                  @title={{collectionData.key}}
                                  @tooltip={{i18n
                                    (concat
                                      "admin.api.scopes.descriptions."
                                      scopeKey
                                      "."
                                      collectionData.key
                                    )
                                  }}
                                  @type="checkbox"
                                  as |field|
                                >
                                  <field.Control />
                                </topicsCollection.Field>
                              </td>
                              <td>
                                <DButton
                                  class="btn-info"
                                  @action={{fn
                                    this.showURLs
                                    collectionData.urls
                                  }}
                                  @icon="link"
                                />
                              </td>
                              <td>
                                <topicsCollection.Object
                                  @name="params"
                                  as |paramsObject paramsObjectData|
                                >
                                  {{#each
                                    (this.paramsObjectKeys paramsObjectData)
                                    as |name|
                                  }}
                                    <paramsObject.Field
                                      @name={{name}}
                                      @showTitle={{false}}
                                      @title={{name}}
                                      @type="input"
                                      as |field|
                                    >
                                      <field.Control placeholder={{name}} />
                                    </paramsObject.Field>
                                  {{/each}}
                                </topicsCollection.Object>
                              </td>
                            </tr>
                          </scopesObject.Collection>
                        {{/each}}
                      </form.Object>
                    </tbody>
                  </table>
                {{/if}}

                <form.Actions>
                  <form.Submit class="save" @label="admin.api_keys.save" />
                  <form.Button
                    class="btn-default"
                    @label="admin.api_keys.cancel"
                    @route="adminApiKeys.index"
                  />
                </form.Actions>
              </Form>
            </DConditionalLoadingSection>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
