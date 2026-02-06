import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiSecretEditorForm from "./ai-secret-editor-form";

export default class AiSecretsListEditor extends Component {
  @service adminPluginNavManager;

  get hasSecrets() {
    return this.args.secrets.content?.length > 0;
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-secrets"
      @label={{i18n "discourse_ai.secrets.short_title"}}
    />
    <section class="ai-secret-list-editor admin-detail">
      {{#if @currentSecret}}
        <AiSecretEditorForm @model={{@currentSecret}} @secrets={{@secrets}} />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.secrets.short_title"}}
          @descriptionLabel={{i18n "discourse_ai.secrets.description"}}
        >
          <:actions as |actions|>
            <actions.Primary
              @label="discourse_ai.secrets.create_new"
              @route="adminPlugins.show.discourse-ai-secrets.new"
              @icon="plus"
              class="ai-secret-list-editor__new-btn"
            />
          </:actions>
        </DPageSubheader>

        {{#if this.hasSecrets}}
          <table class="d-admin-table ai-secret-list-editor__table">
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.secrets.name"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @secrets.content as |secret|}}
                <tr
                  data-secret-id={{secret.id}}
                  class="ai-secret-list__row d-admin-row__content"
                >
                  <td class="d-admin-row__overview">
                    <strong>{{secret.name}}</strong>
                  </td>
                  <td class="d-admin-row__controls">
                    <DButton
                      class="btn btn-default btn-small ai-secret-list__edit-button"
                      @label="discourse_ai.secrets.edit"
                      @route="adminPlugins.show.discourse-ai-secrets.edit"
                      @routeModels={{secret.id}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p>{{i18n "discourse_ai.secrets.no_secrets"}}</p>
        {{/if}}
      {{/if}}
    </section>
  </template>
}
