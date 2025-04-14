import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ApiKeyUrlsModal from "admin/components/modal/api-key-urls";
import { API_KEY_SCOPE_MODES } from "admin/lib/constants";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class AdminConfigAreasApiKeysNew extends Component {
  @service router;
  @service modal;
  @service store;

  @tracked username;
  @tracked loadingScopes = false;
  @tracked scopes = null;

  @tracked generatedApiKey = null;

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
    } catch (error) {
      popupAjaxError(error);
    }
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

  @action
  paramsObjectKeys(paramsObjectData) {
    return Object.keys(paramsObjectData);
  }

  @action
  scopesDataKeys(scopesData) {
    return Object.keys(scopesData);
  }

  <template>
    <BackButton @route="adminApiKeys.index" @label="admin.api_keys.back" />

    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <div class="admin-config-area-card">
          {{#if this.generatedApiKey}}
            <div>{{i18n "admin.api.not_shown_again"}}</div>
            <div class="generated-api-key">{{this.generatedApiKey}}</div>
            <DButton
              @route="adminApiKeys.index"
              @label="admin.api_keys.continue"
              class="continue btn-danger"
            />
          {{else}}
            <ConditionalLoadingSection @isLoading={{this.loadingScopes}}>
              <Form
                @onSubmit={{this.save}}
                @data={{this.formData}}
                @validate={{this.atLeastOneGranularScope}}
                as |form transientData|
              >
                <form.Field
                  @name="description"
                  @title={{i18n "admin.api.description"}}
                  @format="large"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>

                <form.Field
                  @name="user_mode"
                  @title={{i18n "admin.api.user_mode"}}
                  @format="large"
                  @validation="required"
                  as |field|
                >
                  <field.Select as |select|>
                    {{#each this.userModes as |userMode|}}
                      <select.Option
                        @value={{userMode.id}}
                      >{{userMode.name}}</select.Option>
                    {{/each}}
                  </field.Select>
                </form.Field>

                {{#if (eq transientData.user_mode "single")}}
                  <form.Field
                    @name="user"
                    @title={{i18n "admin.api.user"}}
                    @format="large"
                    @validation="required"
                    as |field|
                  >
                    <field.Custom>
                      <EmailGroupUserChooser
                        @value={{this.username}}
                        @onChange={{fn this.updateUsername field}}
                        @options={{hash
                          maximum=1
                          filterPlaceholder="admin.api.user_placeholder"
                        }}
                      />
                    </field.Custom>
                  </form.Field>
                {{/if}}

                <form.Field
                  @name="scope_mode"
                  @title={{i18n "admin.api.scope_mode"}}
                  @format="large"
                  @validation="required"
                  as |field|
                >
                  <field.Select as |select|>
                    {{#each this.scopeModes as |scopeMode|}}
                      <select.Option
                        @value={{scopeMode.id}}
                      >{{scopeMode.name}}</select.Option>
                    {{/each}}
                  </field.Select>
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
                        @name="scopes"
                        class="scopes-table__object"
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
                                  as |field|
                                >
                                  <field.Checkbox />
                                </topicsCollection.Field>
                              </td>
                              <td>
                                <DButton
                                  @icon="link"
                                  @action={{fn
                                    this.showURLs
                                    collectionData.urls
                                  }}
                                  class="btn-info"
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
                                      @title={{name}}
                                      @showTitle={{false}}
                                      as |field|
                                    >
                                      <field.Input placeholder={{name}} />
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
                    @route="adminApiKeys.index"
                    @label="admin.api_keys.cancel"
                    class="btn-default"
                  />
                </form.Actions>
              </Form>
            </ConditionalLoadingSection>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
