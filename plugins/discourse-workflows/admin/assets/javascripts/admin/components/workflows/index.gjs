import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import DiscourseURL, {
  applyQueryParams,
  searchParamsFromPath,
} from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminTable from "./admin-table";
import EmptyState from "./empty-state";

export default class WorkflowsIndex extends Component {
  @service currentUser;
  @service router;
  @service store;

  @tracked loading = false;
  @tracked filtering = false;
  @tracked filteredResultSet = null;
  @tracked nameFilter = null;
  @tracked tagFilter = [];
  @tracked hasWorkflows = this.args.workflows.totalRows > 0;

  #latestRequest = null;

  constructor() {
    super(...arguments);

    const params = searchParamsFromPath(this.router.currentURL);
    this.nameFilter = params.get("filter");
    this.tagFilter = this.normalizeTagFilter(params.get("tags"));

    if (this.hasActiveFilters) {
      // the route model is unfiltered; refetch so deep links apply, and keep
      // the filter bar visible even when the filtered set comes back empty
      this.hasWorkflows = true;
      this.refetch();
    }
  }

  get workflowTags() {
    return this.args.workflowTags ?? [];
  }

  get availableTagNames() {
    return this.workflowTags.map((tag) => tag.name);
  }

  get resultSet() {
    return this.filteredResultSet ?? this.args.workflows;
  }

  get hasActiveFilters() {
    return Boolean(this.nameFilter) || this.tagFilter.length > 0;
  }

  get tagSelection() {
    return this.workflowTags.filter((tag) => this.tagFilter.includes(tag.name));
  }

  normalizeTagName(tag) {
    return (tag || "").trim().toLowerCase().replace(/\s+/g, " ");
  }

  normalizeTagFilter(tagsParam) {
    return (tagsParam || "")
      .split(",")
      .map((tag) => this.normalizeTagName(tag))
      .filter(Boolean)
      .filter((tag) => this.availableTagNames.includes(tag));
  }

  @action
  async loadTags(searchTerm) {
    const term = (searchTerm || "").toLowerCase();
    return this.workflowTags.filter((tag) => tag.name.includes(term));
  }

  async refetch() {
    this.filtering = true;

    const args = {};
    if (this.nameFilter) {
      args.filter = this.nameFilter;
    }
    if (this.tagFilter.length) {
      args.tags = this.tagFilter.join(",");
    }

    const token = (this.#latestRequest = {});
    try {
      const result = await this.store.findAll(
        "discourse-workflows-workflow",
        args
      );
      if (token === this.#latestRequest) {
        this.filteredResultSet = result;
        if (!this.hasActiveFilters) {
          this.hasWorkflows = result.totalRows > 0;
        }
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      if (token === this.#latestRequest) {
        this.filtering = false;
      }
    }
  }

  syncQueryParams() {
    if (!this.router.currentURL) {
      return;
    }

    DiscourseURL.replaceState(
      applyQueryParams(this.router.currentURL, {
        filter: this.nameFilter || null,
        tags: this.tagFilter.length ? this.tagFilter.join(",") : null,
      })
    );
  }

  @action
  applyFilters() {
    this.syncQueryParams();
    this.refetch();
  }

  @action
  onNameFilterChange(event) {
    this.nameFilter = event.target.value || null;
    discourseDebounce(this, this.applyFilters, INPUT_DELAY);
  }

  @action
  onTagFilterChange(selection) {
    this.tagFilter = selection.map((tag) => tag.name);
    this.applyFilters();
  }

  @action
  addTagFilter(tagName, event) {
    event?.preventDefault();

    if (this.tagFilter.includes(tagName)) {
      return;
    }

    this.tagFilter = [...this.tagFilter, tagName];
    this.applyFilters();
  }

  @action
  tagFilterHref(tagName) {
    return getURL(
      applyQueryParams(
        this.router.urlFor("adminPlugins.show.discourse-workflows.index"),
        { tags: tagName }
      )
    );
  }

  @action
  resetFilters() {
    this.nameFilter = null;
    this.tagFilter = [];
    this.applyFilters();
  }

  @action
  async loadMore() {
    if (!this.resultSet.canLoadMore || this.loading) {
      return;
    }

    this.loading = true;
    try {
      await this.resultSet.loadMore();
    } finally {
      this.loading = false;
    }
  }

  @action
  async createWorkflow() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflows.json",
        {
          type: "POST",
          data: {
            workflow: {
              name: i18n("discourse_workflows.default_workflow_name"),
            },
          },
        }
      );
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show",
        result.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  workflowStatusLabel(workflow) {
    if (workflow.activeVersionId && workflow.hasUnpublishedChanges) {
      return "discourse_workflows.unpublished_changes";
    }

    return workflow.activeVersionId
      ? "discourse_workflows.published"
      : "discourse_workflows.unpublished";
  }

  @action
  workflowStatusClass(workflow) {
    if (workflow.activeVersionId && workflow.hasUnpublishedChanges) {
      return "is-unpublished-changes";
    }

    return workflow.activeVersionId ? "is-published" : "is-unpublished";
  }

  <template>
    {{#if this.hasWorkflows}}
      <div class="d-filter-controls workflows-index__filters">
        <div class="d-filter-controls__inputs">
          <DFilterInput
            placeholder={{i18n "discourse_workflows.search_placeholder"}}
            @filterAction={{this.onNameFilterChange}}
            @value={{this.nameFilter}}
            class="d-filter-controls__input"
            @icons={{hash left="magnifying-glass"}}
          />

          <DMultiSelect
            @loadFn={{this.loadTags}}
            @selection={{this.tagSelection}}
            @onChange={{this.onTagFilterChange}}
            @label={{i18n "discourse_workflows.tags.filter_label"}}
            @noResultsLabel={{i18n "discourse_workflows.tags.no_results"}}
            class="workflows-index__tag-filter"
          >
            <:selection as |tag|>{{tag.name}}</:selection>
            <:result as |tag|>
              <span class="workflows-index__tag-filter-name">
                {{tag.name}}
              </span>
              <span class="workflows-index__tag-filter-count">
                {{tag.workflow_count}}
              </span>
            </:result>
          </DMultiSelect>

          {{#unless this.filtering}}
            {{#if this.hasActiveFilters}}
              <DButton
                @icon="arrow-rotate-left"
                @label="filter_controls.reset"
                @action={{this.resetFilters}}
                class="btn-default d-filter-controls__reset"
              />
            {{/if}}
          {{/unless}}
        </div>

        <DButton
          @action={{this.createWorkflow}}
          @label="discourse_workflows.new_workflow"
          @icon="plus"
          class="btn-primary workflows-index__new-btn"
        />
      </div>

      {{#if this.resultSet.content.length}}
        <AdminTable
          @items={{this.resultSet.content}}
          @isLoading={{this.filtering}}
          @canLoadMore={{this.resultSet.canLoadMore}}
          @loadMore={{this.loadMore}}
          @loadingMore={{this.loading}}
          @rowClass="workflows-index__row"
        >
          <:head>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.creator"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.workflow_name"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.last_editor"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.last_update"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.last_run"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.status"
              }}</th>
          </:head>
          <:row as |workflow|>
            <td class="d-table__cell --detail workflows-index__creator">
              <div class="d-table__mobile-label">
                {{i18n "discourse_workflows.creator"}}
              </div>
              {{#if workflow.createdBy}}
                <a
                  href={{workflow.createdBy.path}}
                  class="workflows-index__creator-link"
                >
                  {{dAvatar workflow.createdBy imageSize="tiny"}}
                </a>
              {{/if}}
            </td>
            <td class="d-table__cell --overview workflows-index__name">
              <LinkTo
                @route="adminPlugins.show.discourse-workflows.show"
                @model={{workflow.id}}
                class="d-table__overview-link"
              >
                <strong
                  class="d-table__overview-name"
                >{{workflow.name}}</strong>
                {{#if (eq workflow.lastExecutionStatus "error")}}
                  <span
                    class="workflows-index__warning"
                    role="img"
                    aria-label={{i18n
                      "discourse_workflows.last_execution_failed"
                    }}
                    title={{i18n "discourse_workflows.last_execution_failed"}}
                  >
                    {{dIcon "triangle-exclamation"}}
                  </span>
                {{/if}}
              </LinkTo>
              {{#if workflow.tags.length}}
                <div class="d-table__badges workflows-index__tags">
                  {{#each workflow.tags as |tag|}}
                    <a
                      href={{this.tagFilterHref tag}}
                      class="d-table-badge"
                      title={{i18n "discourse_workflows.tags.filter_by"}}
                      {{on "click" (fn this.addTagFilter tag)}}
                    >
                      <span class="d-table-badge__content">{{tag}}</span>
                    </a>
                  {{/each}}
                </div>
              {{/if}}
            </td>
            <td class="d-table__cell --detail workflows-index__last-editor">
              <div class="d-table__mobile-label">
                {{i18n "discourse_workflows.last_editor"}}
              </div>
              {{#if workflow.updatedBy}}
                <a
                  href={{workflow.updatedBy.path}}
                  class="workflows-index__last-editor-link"
                >
                  {{dAvatar workflow.updatedBy imageSize="tiny"}}
                  <span>{{workflow.updatedBy.username}}</span>
                </a>
              {{/if}}
            </td>
            <td class="d-table__cell --detail workflows-index__last-update">
              <div class="d-table__mobile-label">
                {{i18n "discourse_workflows.last_update"}}
              </div>
              {{dFormatDate workflow.updatedAt format="medium"}}
            </td>
            <td class="d-table__cell --detail workflows-index__last-run">
              <div class="d-table__mobile-label">
                {{i18n "discourse_workflows.last_run"}}
              </div>
              {{#if workflow.lastExecutionAt}}
                {{dFormatDate workflow.lastExecutionAt format="medium"}}
              {{else}}
                {{i18n "discourse_workflows.last_execution_never"}}
              {{/if}}
            </td>
            <td class="d-table__cell --detail">
              <div class="d-table__mobile-label">
                {{i18n "discourse_workflows.status"}}
              </div>
              <span
                class={{dConcatClass
                  "workflows-index__badge"
                  (this.workflowStatusClass workflow)
                }}
              >
                {{i18n (this.workflowStatusLabel workflow)}}
              </span>
            </td>
          </:row>
        </AdminTable>
      {{else if this.hasActiveFilters}}
        <div class="d-filter-controls__no-results workflows-index__no-results">
          <p>{{i18n "discourse_workflows.no_workflows_found"}}</p>
          <DButton
            @icon="arrow-rotate-left"
            @label="filter_controls.reset"
            @action={{this.resetFilters}}
            class="btn-default"
          />
        </div>
      {{/if}}
    {{else}}
      <EmptyState
        @emoji="wave"
        @title={{i18n
          "discourse_workflows.empty_title"
          username=this.currentUser.displayName
        }}
        @description={{i18n "discourse_workflows.empty_description"}}
        @buttonLabel="discourse_workflows.create_first_workflow"
        @onAction={{this.createWorkflow}}
      />
    {{/if}}
  </template>
}
