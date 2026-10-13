import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiDecisionModelEditor from "./ai-decision-model-editor";

export default class AiDecisionModelsListEditor extends Component {
  @service adminPluginNavManager;

  get hasDecisionModels() {
    return this.args.decisionModels.content.length !== 0;
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.decision_models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-decision-models"
    />
    <section class="ai-decision-models-list-editor admin-detail">
      {{#if @currentDecisionModel}}
        <AiDecisionModelEditor
          @decisionModels={{@decisionModels}}
          @model={{@currentDecisionModel}}
        />
      {{else}}
        <DPageSubheader
          @descriptionLabel={{i18n "discourse_ai.decision_models.description"}}
          @titleLabel={{i18n "discourse_ai.decision_models.short_title"}}
        >
          <:actions as |actions|>
            <actions.Primary
              class="ai-decision-models-list-editor__new-button"
              @icon="plus"
              @label="discourse_ai.decision_models.new"
              @route="adminPlugins.show.discourse-ai-decision-models.new"
            />
          </:actions>
        </DPageSubheader>

        {{#if this.hasDecisionModels}}
          <table class="d-table">
            <thead class="d-table__header">
              <tr>
                <th>{{i18n "discourse_ai.decision_models.display_name"}}</th>
                <th>{{i18n "discourse_ai.decision_models.name"}}</th>
                <th>{{i18n "discourse_ai.decision_models.provider"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @decisionModels.content as |decisionModel|}}
                <tr
                  class="ai-decision-models-list__row d-table__row"
                  data-decision-model-id={{decisionModel.id}}
                >
                  <td class="d-table__cell --overview">
                    <strong>{{decisionModel.display_name}}</strong>
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.decision_models.name"}}
                    </div>
                    {{decisionModel.name}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.decision_models.provider"}}
                    </div>
                    {{i18n
                      (concat
                        "discourse_ai.decision_models.providers."
                        decisionModel.provider
                      )
                    }}
                  </td>
                  <td class="d-table__cell --controls">
                    <DButton
                      class="btn-default btn-small ai-decision-models-list__edit-button"
                      @label="discourse_ai.decision_models.edit"
                      @route="adminPlugins.show.discourse-ai-decision-models.edit"
                      @routeModels={{decisionModel.id}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaClass="ai-decision-models-list-editor__empty-new-button"
            @ctaLabel="discourse_ai.decision_models.new"
            @ctaRoute="adminPlugins.show.discourse-ai-decision-models.new"
            @emptyLabel="discourse_ai.decision_models.empty"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
