import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiConceptMergeModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-concept-merge-modal";

const SEED_STATUS_CHANNEL = "/discourse-ai/admin/inferred-concepts/seed";

export default class AiConceptsList extends Component {
  @service adminPluginNavManager;
  @service dialog;
  @service messageBus;
  @service modal;
  @service router;
  @service toasts;

  #filterDebounce = null;
  #isRefreshing = false;
  #isStartingSeed = tracked(false);
  #overrideConcepts = tracked(null);
  #overrideMeta = tracked(null);

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(SEED_STATUS_CHANNEL, this.onSeedStatusUpdate);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#filterDebounce);
    this.messageBus.unsubscribe(SEED_STATUS_CHANNEL, this.onSeedStatusUpdate);
  }

  get concepts() {
    return this.#overrideConcepts.value ?? this.args.model?.ai_concepts ?? [];
  }

  get meta() {
    return this.#overrideMeta.value ?? this.args.model?.meta ?? {};
  }

  get counts() {
    return this.meta.counts || { active: 0, candidate: 0, retired: 0 };
  }

  get totalAll() {
    return (
      (this.counts.active || 0) +
      (this.counts.candidate || 0) +
      (this.counts.retired || 0)
    );
  }

  get hasAnyConcepts() {
    return this.totalAll > 0;
  }

  get hasMore() {
    return Boolean(this.meta.has_more);
  }

  get showPostsColumn() {
    return this.meta.posts_enabled !== false;
  }

  get canRunCuration() {
    return Boolean(this.meta.enabled && this.meta.embeddings_enabled);
  }

  get isStartingSeed() {
    return this.#isStartingSeed.value;
  }

  get seedStatus() {
    return this.meta.seed_status || null;
  }

  get isSeeding() {
    return (
      this.seedStatus?.status === "queued" ||
      this.seedStatus?.status === "running"
    );
  }

  get seedProgressMessage() {
    if (this.seedStatus?.total) {
      return i18n("discourse_ai.concepts.seed.running_progress", {
        processed: this.seedStatus.processed || 0,
        total: this.seedStatus.total,
      });
    }

    return i18n("discourse_ai.concepts.seed.queued");
  }

  get selectedStatus() {
    return this.args.status || "all";
  }

  get statusOptions() {
    return [
      { value: "all", label: i18n("discourse_ai.concepts.statuses.all") },
      {
        value: "active",
        label: i18n("discourse_ai.concepts.statuses.active_count", {
          count: this.counts.active || 0,
        }),
      },
      {
        value: "candidate",
        label: i18n("discourse_ai.concepts.statuses.candidate_count", {
          count: this.counts.candidate || 0,
        }),
      },
      {
        value: "retired",
        label: i18n("discourse_ai.concepts.statuses.retired_count", {
          count: this.counts.retired || 0,
        }),
      },
    ];
  }

  get sortOptions() {
    return [
      { value: "usage", label: i18n("discourse_ai.concepts.sort.usage") },
      { value: "name", label: i18n("discourse_ai.concepts.sort.name") },
      {
        value: "created_at",
        label: i18n("discourse_ai.concepts.sort.created_at"),
      },
    ];
  }

  @action
  resetOverrides() {
    this.#overrideConcepts.value = null;
    this.#overrideMeta.value = null;
  }

  @action
  onTextFilterChange(event) {
    const value = event.target?.value || "";
    this.#filterDebounce = discourseDebounce(
      this,
      this.#applyQuery,
      { filter: value },
      INPUT_DELAY
    );
  }

  @action
  onStatusChange(status) {
    this.#applyQuery({ status });
  }

  @action
  onSortChange(order) {
    this.#applyQuery({ order });
  }

  @action
  clearFilters() {
    this.#applyQuery({ status: "all", filter: "" });
  }

  @action
  async loadMore() {
    const nextPage = (this.meta.page || 1) + 1;

    try {
      const data = { page: nextPage };
      if (this.selectedStatus !== "all") {
        data.status = this.selectedStatus;
      }
      if (this.args.filter?.trim()) {
        data.filter = this.args.filter.trim();
      }
      if (this.args.order && this.args.order !== "usage") {
        data.order = this.args.order;
      }

      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-concepts.json",
        {
          data,
        }
      );

      this.#overrideConcepts.value = [
        ...this.concepts,
        ...(response.ai_concepts || []),
      ];
      this.#overrideMeta.value = response.meta;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async runCuration() {
    try {
      await ajax("/admin/plugins/discourse-ai/ai-concepts/curate.json", {
        type: "POST",
      });
      this.toasts.success({
        data: { message: i18n("discourse_ai.concepts.curation_enqueued") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async startSeed() {
    if (this.#isStartingSeed.value) {
      return;
    }

    this.#isStartingSeed.value = true;

    try {
      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-concepts/seed.json",
        {
          type: "POST",
        }
      );

      this.#overrideMeta.value = {
        ...this.meta,
        seed_status: response.seed_status,
      };

      this.toasts.success({
        data: { message: i18n("discourse_ai.concepts.seed.enqueued") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.#isStartingSeed.value = false;
    }
  }

  @action
  refreshList() {
    return this.#refreshList();
  }

  @action
  onSeedStatusUpdate(data) {
    if (!data?.status) {
      return;
    }

    const current = this.seedStatus;
    const sameRun =
      !data.run_id || !current?.run_id || data.run_id === current.run_id;

    if (sameRun && current) {
      if (
        (current.status === "completed" || current.status === "failed") &&
        (data.status === "queued" || data.status === "running")
      ) {
        return;
      }

      if (
        current.status === "running" &&
        data.status === "running" &&
        (data.processed || 0) < (current.processed || 0)
      ) {
        return;
      }
    }

    const hadNoConcepts = !this.hasAnyConcepts;
    this.#overrideMeta.value = {
      ...this.meta,
      seed_status: data,
    };

    if (
      data.status === "completed" ||
      (hadNoConcepts && data.status === "running" && (data.processed || 0) > 0)
    ) {
      this.#refreshList();
    }
  }

  @action
  async promoteConcept(concept, closeMenu) {
    closeMenu?.();
    await this.#updateConceptStatus(
      concept,
      "active",
      "discourse_ai.concepts.promoted"
    );
  }

  @action
  async toggleRetireConcept(concept, closeMenu) {
    closeMenu?.();
    const nextStatus = concept.status === "retired" ? "active" : "retired";
    const messageKey =
      nextStatus === "retired"
        ? "discourse_ai.concepts.retired"
        : "discourse_ai.concepts.reactivated";
    await this.#updateConceptStatus(concept, nextStatus, messageKey);
  }

  @action
  openMergeModal(concept, closeMenu) {
    closeMenu?.();

    this.modal.show(AiConceptMergeModal, {
      model: {
        concept,
        onMerged: () => this.#refreshList(),
      },
    });
  }

  @action
  deleteConcept(concept, closeMenu) {
    closeMenu?.();

    return this.dialog.deleteConfirm({
      message: i18n("discourse_ai.concepts.confirm_delete", {
        name: concept.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/discourse-ai/ai-concepts/${concept.id}.json`,
            { type: "DELETE" }
          );
          this.toasts.success({
            data: { message: i18n("discourse_ai.concepts.deleted") },
            duration: "short",
          });
          await this.#refreshList();
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  #applyQuery(updates) {
    if (this.args.onQueryChange) {
      this.args.onQueryChange(updates);
      return;
    }

    const nextStatus =
      "status" in updates ? updates.status || "all" : this.selectedStatus;
    const nextFilter =
      "filter" in updates ? (updates.filter || "").trim() : this.args.filter;
    const nextOrder =
      "order" in updates
        ? updates.order || "usage"
        : this.args.order || "usage";

    this.router.replaceWith({
      queryParams: {
        status: nextStatus === "all" ? null : nextStatus,
        filter: nextFilter || null,
        order: nextOrder === "usage" ? null : nextOrder,
      },
    });
  }

  async #refreshList() {
    if (this.#isRefreshing) {
      return;
    }

    this.#isRefreshing = true;

    try {
      const data = {};
      if (this.selectedStatus !== "all") {
        data.status = this.selectedStatus;
      }
      if (this.args.filter?.trim()) {
        data.filter = this.args.filter.trim();
      }
      if (this.args.order && this.args.order !== "usage") {
        data.order = this.args.order;
      }

      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-concepts.json",
        {
          data,
        }
      );

      if (this.isDestroying) {
        return;
      }

      this.#overrideConcepts.value = response.ai_concepts || [];
      this.#overrideMeta.value = response.meta;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.#isRefreshing = false;
    }
  }

  async #updateConceptStatus(concept, status, toastKey) {
    try {
      await ajax(`/admin/plugins/discourse-ai/ai-concepts/${concept.id}.json`, {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ ai_concept: { status } }),
      });
      this.toasts.success({
        data: { message: i18n(toastKey) },
        duration: "short",
      });
      await this.#refreshList();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.concepts.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-concepts"
    />

    <section
      class="ai-concepts-list admin-detail"
      ...attributes
      {{didUpdate this.resetOverrides @model}}
    >
      <DPageSubheader
        @descriptionLabel={{i18n "discourse_ai.concepts.description"}}
        @titleLabel={{i18n "discourse_ai.concepts.short_title"}}
      >
        <:actions as |actions|>
          {{#if this.canRunCuration}}
            <actions.Default
              class="ai-concepts-list__curate-btn"
              @action={{this.runCuration}}
              @icon="arrows-rotate"
              @label="discourse_ai.concepts.run_curation"
            />
          {{/if}}
          <actions.Primary
            class="ai-concepts-list__new-btn"
            @icon="plus"
            @label="discourse_ai.concepts.new"
            @route="adminPlugins.show.discourse-ai-concepts.new"
          />
        </:actions>
      </DPageSubheader>

      {{#unless this.meta.enabled}}
        <div class="alert alert-info ai-concepts-list__disabled-notice">
          {{i18n "discourse_ai.concepts.disabled_notice"}}
          <LinkTo @route="adminPlugins.show.discourse-ai-features">
            {{i18n "discourse_ai.concepts.disabled_notice_link"}}
          </LinkTo>
        </div>
      {{/unless}}

      {{#if this.hasAnyConcepts}}
        {{#if this.isSeeding}}
          <div class="alert alert-info ai-concepts-list__seed-banner">
            <span>{{this.seedProgressMessage}}</span>
            <DButton
              class="btn-default btn-small ai-concepts-list__refresh-btn"
              @action={{this.refreshList}}
              @icon="arrows-rotate"
              @label="discourse_ai.concepts.seed.refresh"
            />
          </div>
        {{/if}}

        <div class="ai-concepts-list__controls">
          <DFilterControls
            @array={{this.concepts}}
            @defaultDropdownValue="all"
            @defaultSort="usage"
            @dropdownOptions={{this.statusOptions}}
            @dropdownValue={{this.selectedStatus}}
            @initialTextFilter={{@filter}}
            @inputPlaceholder={{i18n
              "discourse_ai.concepts.filter_placeholder"
            }}
            @onDropdownFilterChange={{this.onStatusChange}}
            @onResetFilters={{this.clearFilters}}
            @onSortChange={{this.onSortChange}}
            @onTextFilterChange={{this.onTextFilterChange}}
            @showNoResults={{false}}
            @sortOptions={{this.sortOptions}}
          />
        </div>

        {{#if this.concepts.length}}
          <table class="d-table ai-concepts-list__table">
            <thead class="d-table__header">
              <tr>
                <th>{{i18n "discourse_ai.concepts.columns.name"}}</th>
                <th>{{i18n "discourse_ai.concepts.columns.status"}}</th>
                <th>{{i18n "discourse_ai.concepts.columns.topics"}}</th>
                {{#if this.showPostsColumn}}
                  <th>{{i18n "discourse_ai.concepts.columns.posts"}}</th>
                {{/if}}
                <th></th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each this.concepts as |concept|}}
                <tr
                  class="ai-concepts-list__row d-table__row"
                  data-concept-id={{concept.id}}
                >
                  <td class="d-table__cell --overview">
                    <LinkTo
                      class="d-table__overview-link"
                      @model={{concept.id}}
                      @route="adminPlugins.show.discourse-ai-concepts.edit"
                    >
                      <span class="d-table__overview-name">
                        {{concept.name}}
                      </span>
                    </LinkTo>
                    {{#if concept.description}}
                      <div class="ai-concepts-list__description">
                        {{concept.description}}
                      </div>
                    {{/if}}
                    {{#if concept.aliases.length}}
                      <div class="ai-concepts-list__aliases">
                        {{#each concept.aliases as |aliasName|}}
                          <span class="ai-concepts-list__alias">
                            {{aliasName}}
                          </span>
                        {{/each}}
                      </div>
                    {{/if}}
                    {{#if concept.parent_name}}
                      <div class="ai-concepts-list__parent">
                        {{i18n
                          "discourse_ai.concepts.parent_label"
                          name=concept.parent_name
                        }}
                      </div>
                    {{/if}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.concepts.columns.status"}}
                    </div>
                    <span
                      class="ai-concept-status"
                      data-status={{concept.status}}
                    >
                      {{i18n
                        (concat
                          "discourse_ai.concepts.statuses." concept.status
                        )
                      }}
                    </span>
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.concepts.columns.topics"}}
                    </div>
                    {{concept.topics_count}}
                  </td>
                  {{#if this.showPostsColumn}}
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">
                        {{i18n "discourse_ai.concepts.columns.posts"}}
                      </div>
                      {{concept.posts_count}}
                    </td>
                  {{/if}}
                  <td class="d-table__cell --controls">
                    <div class="d-table__cell-actions">
                      <DButton
                        class="btn-default btn-small ai-concepts-list__edit-btn"
                        @label="discourse_ai.concepts.edit"
                        @route="adminPlugins.show.discourse-ai-concepts.edit"
                        @routeModels={{concept.id}}
                      />
                      <DMenu
                        class="btn-default btn-small ai-concepts-list__actions-menu"
                        @icon="ellipsis-vertical"
                        @identifier="ai-concept-actions"
                        @title={{i18n "discourse_ai.concepts.open_actions"}}
                      >
                        <:content as |args|>
                          <DDropdownMenu as |dropdown|>
                            {{#if (eq concept.status "candidate")}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent ai-concepts-list__promote-btn"
                                  @action={{fn
                                    this.promoteConcept
                                    concept
                                    args.close
                                  }}
                                  @icon="check"
                                  @label="discourse_ai.concepts.promote"
                                />
                              </dropdown.item>
                            {{/if}}

                            {{#unless (eq concept.status "retired")}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent ai-concepts-list__merge-btn"
                                  @action={{fn
                                    this.openMergeModal
                                    concept
                                    args.close
                                  }}
                                  @icon="code-merge"
                                  @label="discourse_ai.concepts.merge.action"
                                />
                              </dropdown.item>
                            {{/unless}}

                            <dropdown.item>
                              <DButton
                                class="btn-transparent ai-concepts-list__retire-btn"
                                @action={{fn
                                  this.toggleRetireConcept
                                  concept
                                  args.close
                                }}
                                @icon="box-archive"
                                @label={{if
                                  (eq concept.status "retired")
                                  "discourse_ai.concepts.reactivate"
                                  "discourse_ai.concepts.retire"
                                }}
                              />
                            </dropdown.item>

                            <dropdown.item>
                              <DButton
                                class="btn-transparent btn-danger ai-concepts-list__delete-btn"
                                @action={{fn
                                  this.deleteConcept
                                  concept
                                  args.close
                                }}
                                @icon="trash-can"
                                @label="discourse_ai.concepts.delete"
                              />
                            </dropdown.item>
                          </DDropdownMenu>
                        </:content>
                      </DMenu>
                    </div>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>

          {{#if this.hasMore}}
            <div class="ai-concepts-list__pagination">
              <DButton
                class="btn-default ai-concepts-list__load-more"
                @action={{this.loadMore}}
                @label="discourse_ai.concepts.load_more"
              />
            </div>
          {{/if}}
        {{else}}
          <div class="ai-concepts-list__no-results">
            <span>{{i18n "discourse_ai.concepts.no_results"}}</span>
            <DButton
              class="btn-default btn-small"
              @action={{this.clearFilters}}
              @label="discourse_ai.concepts.clear_filters"
            />
          </div>
        {{/if}}
      {{else}}
        <AdminConfigAreaEmptyList
          class="ai-concepts-list__empty"
          @ctaLabel={{unless this.canRunCuration "discourse_ai.concepts.new"}}
          @ctaRoute={{unless
            this.canRunCuration
            "adminPlugins.show.discourse-ai-concepts.new"
          }}
          @emptyLabel="discourse_ai.concepts.empty"
        >
          {{#if this.canRunCuration}}
            <p class="ai-concepts-list__empty-description">
              {{i18n "discourse_ai.concepts.empty_description"}}
            </p>

            {{#if this.isSeeding}}
              <div class="alert alert-info ai-concepts-list__seed-status">
                {{this.seedProgressMessage}}
              </div>
            {{else if (eq this.seedStatus.status "failed")}}
              <div class="alert alert-error ai-concepts-list__seed-error">
                {{i18n "discourse_ai.concepts.seed.failed"}}
              </div>
            {{/if}}

            <div class="ai-concepts-list__empty-actions">
              {{#if this.isSeeding}}
                <DButton
                  class="btn-default ai-concepts-list__refresh-btn"
                  @action={{this.refreshList}}
                  @icon="arrows-rotate"
                  @label="discourse_ai.concepts.seed.refresh"
                />
              {{else}}
                <DButton
                  class="btn-primary ai-concepts-list__seed-btn"
                  @action={{this.startSeed}}
                  @disabled={{this.isStartingSeed}}
                  @icon="discourse-ai"
                  @label="discourse_ai.concepts.seed.action"
                />
              {{/if}}

              <DButton
                class="btn-default ai-concepts-list__empty-new-btn"
                @icon="plus"
                @label="discourse_ai.concepts.new"
                @route="adminPlugins.show.discourse-ai-concepts.new"
              />
            </div>
          {{/if}}
        </AdminConfigAreaEmptyList>
      {{/if}}
    </section>
  </template>
}
