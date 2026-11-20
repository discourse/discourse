import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ApiKeyScopeFields from "discourse/admin/components/api-key-scope-fields";
import GeneratedApiKey from "discourse/admin/components/generated-api-key";
import {
  buildScopesFormData,
  loadApiKeyScopes,
  scopesPayload,
  selectedScopes,
  validateGranularScopes,
} from "discourse/admin/lib/api-key-scopes";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import { i18n } from "discourse-i18n";

/** @import { ApiKeyScopeDefinition, SelectedApiKeyScope } from "discourse/admin/lib/api-key-scopes" */
/**
 * @typedef {{
 *   description: string,
 *   scopeMode: "global" | "read_only" | "granular",
 *   scopes: SelectedApiKeyScope[] | null
 * }} CreatedApiKeyData
 */
export default class AdminConfigAreasApiKeysNew extends Component {
  @service store;

  @tracked username;
  @tracked loadingScopes = false;

  /** @type {Record<string, ApiKeyScopeDefinition[]> | null} */
  @tracked scopes = null;

  /** @type {string | null} */
  @tracked generatedApiKey = null;

  /** @type {CreatedApiKeyData | null} */
  @tracked createdKeyData = null;

  userModes = [
    { id: "all", name: i18n("admin.api.all_users") },
    { id: "single", name: i18n("admin.api.single_user") },
  ];

  validateGranularScopes = validateGranularScopes;

  /** @type {ApiKeyScopeDefinition[] | null} */
  globalScopes = null;

  constructor() {
    super(...arguments);
    this.#loadScopes();
  }

  @cached
  get formData() {
    return {
      user_mode: "all",
      scope_mode: "global",
      scopes: buildScopesFormData(this.scopes),
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

    const scopes = scopesPayload(
      data.scope_mode,
      data.scopes,
      this.globalScopes
    );
    if (scopes) {
      payload.scopes = scopes;
    }

    if (data.user_mode === "single") {
      payload.username = data.user;
    }

    try {
      const result = await this.store.createRecord("api-key").save(payload);
      this.generatedApiKey = result.payload.key;
      this.createdKeyData = {
        description: data.description,
        scopeMode: data.scope_mode,
        scopes:
          data.scope_mode === "granular" ? selectedScopes(data.scopes) : null,
      };
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #loadScopes() {
    try {
      this.loadingScopes = true;
      const { globalScopes, scopes } = await loadApiKeyScopes();
      this.globalScopes = globalScopes;
      this.scopes = scopes;
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
            <GeneratedApiKey
              @apiKey={{this.generatedApiKey}}
              @details={{this.createdKeyData}}
            >
              <DButton
                class="continue btn-default"
                @label="admin.api_keys.continue"
                @route="adminApiKeys.index"
              />
            </GeneratedApiKey>
          {{else}}
            <DConditionalLoadingSection @isLoading={{this.loadingScopes}}>
              <Form
                @data={{this.formData}}
                @onSubmit={{this.save}}
                @validate={{this.validateGranularScopes}}
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

                <ApiKeyScopeFields
                  @form={{form}}
                  @transientData={{transientData}}
                />

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
