import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import I18n, { i18n } from "discourse-i18n";
import AiCreditAllocationStatus from "discourse/plugins/discourse-ai/discourse/components/ai-credit-allocation-status";
import AiDefaultLlmSelector from "./ai-default-llm-selector.gjs";
import AiLlmUsages from "./ai-llm-usages.gjs";

const ALL = "all";

export function modelTypes() {
  return ["llm", "embedding", "decision"];
}

function llmDescription(llm) {
  const key = `discourse_ai.llms.model_description.${llm.provider}-${llm.name}`;
  const parts = [];

  if (I18n.lookup(key, { ignoreMissing: true })) {
    parts.push(i18n(key));
  }
  if (llm.id < 0) {
    parts.push(
      i18n("discourse_ai.llms.preseeded_model_description", {
        model: llm.name,
      })
    );
  }

  return parts.join(" ");
}

export default class AiModelsList extends Component {
  @service adminPluginNavManager;
  @service router;

  @tracked filterValue = "";

  get types() {
    return modelTypes();
  }

  get selectedType() {
    return this.types.includes(this.args.type) ? this.args.type : ALL;
  }

  get typeOptions() {
    return [
      { value: ALL, label: i18n("discourse_ai.models.filters.all") },
      ...this.types.map((type) => ({
        value: type,
        label: i18n(`discourse_ai.models.type_filters.${type}`),
      })),
    ];
  }

  get rows() {
    const llmRows = this.args.llms.content.map((llm) => ({
      key: `llm-${llm.id}`,
      type: "llm",
      dataId: llm.name,
      name: llm.display_name,
      provider: i18n(`discourse_ai.llms.providers.${llm.provider}`),
      description: llmDescription(llm),
      editRoute: "adminPlugins.show.discourse-ai-llms.edit",
      editModel: llm.id,
      creditAllocation: llm.llm_credit_allocation,
      llm,
    }));

    const embeddingRows = this.args.embeddings.content.map((embedding) => ({
      key: `embedding-${embedding.id}`,
      type: "embedding",
      dataId: embedding.id,
      name: embedding.display_name,
      provider: i18n(`discourse_ai.embeddings.providers.${embedding.provider}`),
      editRoute: "adminPlugins.show.discourse-ai-embeddings.edit",
      editModel: embedding.id,
      seeded: embedding.seeded,
    }));

    const decisionRows = (this.args.decisionModels?.content ?? []).map(
      (decisionModel) => ({
        key: `decision-${decisionModel.id}`,
        type: "decision",
        dataId: decisionModel.id,
        name: decisionModel.display_name,
        provider: i18n(
          `discourse_ai.decision_models.providers.${decisionModel.provider}`
        ),
        description: decisionModel.seeded
          ? i18n("discourse_ai.decision_models.seeded_description")
          : null,
        editRoute: decisionModel.seeded
          ? null
          : "adminPlugins.show.discourse-ai-decision-models.edit",
        editModel: decisionModel.id,
        creditAllocation: decisionModel.credit_allocation,
      })
    );

    return [...llmRows, ...embeddingRows, ...decisionRows];
  }

  get filteredRows() {
    let rows = this.rows;

    if (this.selectedType !== ALL) {
      rows = rows.filter((row) => row.type === this.selectedType);
    }

    const term = this.filterValue.trim().toLowerCase();
    if (term) {
      rows = rows.filter(
        (row) =>
          row.name?.toLowerCase().includes(term) ||
          row.provider?.toLowerCase().includes(term)
      );
    }

    return rows;
  }

  @action
  onFilterChange(event) {
    this.filterValue = event.target?.value || "";
  }

  @action
  onTypeChange(type) {
    this.router.transitionTo({
      queryParams: { type: type === ALL ? null : type },
    });
  }

  @action
  resetFilters() {
    this.filterValue = "";
    this.onTypeChange(ALL);
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models"
    />
    <section class="ai-models-list admin-detail">
      <DPageSubheader
        @descriptionLabel={{i18n "discourse_ai.models.description"}}
        @titleLabel={{i18n "discourse_ai.models.short_title"}}
      >
        <:actions as |actions|>
          <actions.Primary
            class="ai-models-list__new-button"
            @icon="plus"
            @label="discourse_ai.models.new"
            @route="adminPlugins.show.discourse-ai-models.new"
          />
        </:actions>
      </DPageSubheader>

      {{#if this.rows.length}}
        <div class="ai-models-list__controls">
          <DNativeSelect
            class="ai-models-list__type-filter"
            @includeNone={{false}}
            @onChange={{this.onTypeChange}}
            @value={{this.selectedType}}
            as |select|
          >
            {{#each this.typeOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.label}}
              </select.Option>
            {{/each}}
          </DNativeSelect>

          <DFilterInput
            class="admin-filter__input"
            placeholder={{i18n "discourse_ai.models.filters.text"}}
            @filterAction={{this.onFilterChange}}
            @icons={{hash left="magnifying-glass"}}
            @value={{this.filterValue}}
          />
        </div>

        {{#if (eq this.selectedType "llm")}}
          <AiDefaultLlmSelector />
        {{/if}}

        {{#if this.filteredRows.length}}
          <table class="d-table ai-models-list__table">
            <thead class="d-table__header">
              <tr>
                <th>{{i18n "discourse_ai.models.name"}}</th>
                <th>{{i18n "discourse_ai.models.type"}}</th>
                <th>{{i18n "discourse_ai.models.provider"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.filteredRows key="key" as |row|}}
                <tr
                  class="ai-models-list__row d-table__row
                    {{if (eq row.type 'llm') 'ai-llm-list__row'}}"
                  data-llm-id={{if row.llm row.dataId}}
                  data-model-id={{row.dataId}}
                  data-model-type={{row.type}}
                >
                  <td class="d-table__cell --overview">
                    <div class="ai-models-list__name">
                      <strong>{{row.name}}</strong>
                    </div>
                    {{#if row.description}}
                      <div class="ai-models-list__description">
                        {{row.description}}
                      </div>
                    {{/if}}
                    {{#if row.llm}}
                      <AiLlmUsages @usages={{row.llm.used_by}} />
                    {{/if}}
                    {{#if row.creditAllocation}}
                      <AiCreditAllocationStatus
                        @allocation={{row.creditAllocation}}
                      />
                    {{/if}}
                  </td>
                  <td class="d-table__cell --detail ai-models-list__type">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.models.type"}}
                    </div>
                    {{i18n (concat "discourse_ai.models.types." row.type)}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.models.provider"}}
                    </div>
                    {{row.provider}}
                  </td>
                  <td class="d-table__cell --controls">
                    {{#if row.seeded}}
                      <DTooltip>
                        <:trigger>
                          <DButton
                            class="btn btn-default btn-small disabled"
                            @label="discourse_ai.models.edit"
                          />
                        </:trigger>
                        <:content>
                          {{i18n "discourse_ai.embeddings.seeded_warning"}}
                        </:content>
                      </DTooltip>
                    {{else if row.editRoute}}
                      <DButton
                        class="btn btn-default btn-small ai-models-list__edit-button"
                        @label="discourse_ai.models.edit"
                        @route={{row.editRoute}}
                        @routeModels={{row.editModel}}
                      />
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <div class="ai-models-list__no-results">
            <h3>{{i18n "discourse_ai.models.filters.no_results"}}</h3>
            <DButton
              class="btn-default"
              @action={{this.resetFilters}}
              @icon="arrow-rotate-left"
              @label="discourse_ai.models.filters.reset"
            />
          </div>
        {{/if}}
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaClass="ai-models-list__empty-new-button"
          @ctaLabel="discourse_ai.models.new"
          @ctaRoute="adminPlugins.show.discourse-ai-models.new"
          @emptyLabel="discourse_ai.models.empty"
        />
      {{/if}}
    </section>
  </template>
}
