import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ApiKeyUrlsModal from "discourse/admin/components/modal/api-key-urls";
import { API_KEY_SCOPE_MODES } from "discourse/admin/lib/constants";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Scope mode select and granular scopes table for an API key FormKit form.
 * The form data needs `scope_mode`, plus `scopes` built with
 * `buildScopesFormData`.
 */
export default class ApiKeyScopeFields extends Component {
  @service modal;

  scopeModes = API_KEY_SCOPE_MODES.map((scopeMode) => {
    return { id: scopeMode, name: i18n(`admin.api.scopes.${scopeMode}`) };
  });

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

  <template>
    <@form.Field
      @description={{@scopeModeDescription}}
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
    </@form.Field>

    {{#if (eq @transientData.scope_mode "granular")}}
      <@form.Section
        class="api-key-scopes"
        @subtitle={{i18n "admin.api.scopes.description"}}
        @title={{i18n "admin.api.scopes.title"}}
      >
        <table class="scopes-table grid">
          <thead>
            <tr>
              <td></td>
              <td>{{i18n "admin.api.scopes.allowed_urls"}}</td>
              <td>{{i18n "admin.api.scopes.optional_allowed_parameters"}}</td>
            </tr>
          </thead>
          <tbody>
            <@form.Object
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
                        @action={{fn this.showURLs collectionData.urls}}
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
            </@form.Object>
          </tbody>
        </table>
      </@form.Section>
    {{/if}}
  </template>
}
