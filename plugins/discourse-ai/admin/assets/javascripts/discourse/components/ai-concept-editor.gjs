import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AiConceptChooser from "discourse/plugins/discourse-ai/discourse/components/ai-concept-chooser";
import AiConceptMergeModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-concept-merge-modal";

const CONCEPT_STATUSES = ["active", "candidate", "retired"];

function formatSimilarity(value) {
  return `${Math.round((Number(value) || 0) * 100)}%`;
}

export default class AiConceptEditor extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service toasts;

  #savedConcept = tracked(null);

  get concept() {
    return this.#savedConcept.value ?? this.args.model.concept;
  }

  get statusOptions() {
    return CONCEPT_STATUSES.map((status) => ({
      value: status,
      label: i18n(`discourse_ai.concepts.statuses.${status}`),
    }));
  }

  get initialParent() {
    if (this.concept.parent_id && this.concept.parent_name) {
      return {
        id: this.concept.parent_id,
        name: this.concept.parent_name,
      };
    }

    return null;
  }

  get canMerge() {
    return !this.args.model.isNew && this.concept.status !== "retired";
  }

  get cardHeading() {
    return this.args.model.isNew
      ? "discourse_ai.concepts.new"
      : "discourse_ai.concepts.edit_heading";
  }

  get coOccurringConcepts() {
    return this.args.model.coOccurringConcepts || [];
  }

  get neighborConcepts() {
    return this.args.model.neighborConcepts || [];
  }

  get topicsTotal() {
    return (
      this.args.model.topicsTotal ??
      this.concept.topics_count ??
      (this.args.model.topics || []).length
    );
  }

  get taggedTopicsHeading() {
    return i18n("discourse_ai.concepts.tagged_topics_count", {
      count: this.topicsTotal,
    });
  }

  get topicsSummary() {
    const displayed = (this.args.model.topics || []).length;
    if (displayed > 0 && this.topicsTotal > displayed) {
      return i18n("discourse_ai.concepts.showing_top_topics", {
        shown: displayed,
        total: this.topicsTotal,
      });
    }

    return null;
  }

  @cached
  get formData() {
    const concept = this.concept;

    return {
      name: concept.name || "",
      description: concept.description || "",
      aliases: (concept.aliases || []).join(", "),
      status: concept.status || "active",
      parent_id: concept.parent_id ?? null,
    };
  }

  @action
  async save(data) {
    const payload = {
      ai_concept: {
        name: data.name.trim(),
        description: (data.description || "").trim(),
        aliases: this.#parseAliases(data.aliases),
        status: data.status,
        parent_id: data.parent_id ? Number(data.parent_id) : null,
      },
    };

    try {
      if (this.args.model.isNew) {
        await ajax("/admin/plugins/discourse-ai/ai-concepts.json", {
          type: "POST",
          contentType: "application/json",
          data: JSON.stringify(payload),
        });
        this.toasts.success({
          data: { message: i18n("discourse_ai.concepts.saved") },
          duration: "short",
        });
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-concepts.index"
        );
      } else {
        const response = await ajax(
          `/admin/plugins/discourse-ai/ai-concepts/${this.concept.id}.json`,
          {
            type: "PUT",
            contentType: "application/json",
            data: JSON.stringify(payload),
          }
        );
        this.#savedConcept.value = response.ai_concept;
        this.toasts.success({
          data: { message: i18n("discourse_ai.concepts.saved") },
          duration: "short",
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  openMergeModal() {
    this.modal.show(AiConceptMergeModal, {
      model: {
        concept: this.concept,
        onMerged: (canonical) => {
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-concepts.edit",
            canonical.id
          );
        },
      },
    });
  }

  @action
  deleteConcept() {
    return this.dialog.deleteConfirm({
      message: i18n("discourse_ai.concepts.confirm_delete", {
        name: this.concept.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/discourse-ai/ai-concepts/${this.concept.id}.json`,
            { type: "DELETE" }
          );
          this.toasts.success({
            data: { message: i18n("discourse_ai.concepts.deleted") },
            duration: "short",
          });
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-concepts.index"
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  resetSavedConcept() {
    this.#savedConcept.value = null;
  }

  #parseAliases(raw) {
    return String(raw || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  }

  <template>
    <div
      class="ai-concept-editor admin-detail"
      ...attributes
      {{didUpdate this.resetSavedConcept @model.concept}}
    >
      <BackButton
        @label="discourse_ai.concepts.back"
        @route="adminPlugins.show.discourse-ai-concepts.index"
      />

      <AdminConfigAreaCard
        class="ai-concept-editor__card"
        @heading={{this.cardHeading}}
      >
        <:content>
          <Form
            class="ai-concept-editor__form"
            @data={{this.formData}}
            @onSubmit={{this.save}}
            as |form|
          >
            <form.Field
              @format="large"
              @name="name"
              @title={{i18n "discourse_ai.concepts.form.name"}}
              @type="input"
              @validation="required|length:1,80"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Field
              @format="large"
              @helpText={{i18n "discourse_ai.concepts.form.description_help"}}
              @name="description"
              @title={{i18n "discourse_ai.concepts.form.description"}}
              @type="textarea"
              @validation="length:0,1000"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Field
              @format="large"
              @helpText={{i18n "discourse_ai.concepts.form.aliases_help"}}
              @name="aliases"
              @title={{i18n "discourse_ai.concepts.form.aliases"}}
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Field
              @format="medium"
              @name="status"
              @title={{i18n "discourse_ai.concepts.form.status"}}
              @type="select"
              @validation="required"
              as |field|
            >
              <field.Control @includeNone={{false}} as |select|>
                {{#each this.statusOptions as |option|}}
                  <select.Option @value={{option.value}}>
                    {{option.label}}
                  </select.Option>
                {{/each}}
              </field.Control>
            </form.Field>

            <form.Field
              @format="large"
              @name="parent_id"
              @title={{i18n "discourse_ai.concepts.form.parent"}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <AiConceptChooser
                  class="ai-concept-editor__parent-chooser"
                  @excludeId={{this.concept.id}}
                  @onChange={{field.set}}
                  @options={{hash
                    clearable=true
                    none="discourse_ai.concepts.form.parent_none"
                  }}
                  @selectedConcept={{this.initialParent}}
                  @value={{field.value}}
                />
              </field.Control>
            </form.Field>

            <form.Actions>
              <form.Submit />

              {{#if this.canMerge}}
                <form.Button
                  class="btn-default ai-concept-editor__merge-btn"
                  @action={{this.openMergeModal}}
                  @icon="code-merge"
                  @label="discourse_ai.concepts.merge.action"
                />
              {{/if}}

              {{#unless @model.isNew}}
                <form.Button
                  class="btn-danger ai-concept-editor__delete-btn"
                  @action={{this.deleteConcept}}
                  @icon="trash-can"
                  @label="discourse_ai.concepts.delete"
                />
              {{/unless}}
            </form.Actions>
          </Form>
        </:content>
      </AdminConfigAreaCard>

      {{#unless @model.isNew}}
        {{#if @model.children.length}}
          <AdminConfigAreaCard
            class="ai-concept-editor__children-card"
            @heading="discourse_ai.concepts.children"
          >
            <:content>
              <ul class="ai-concept-editor__children-list">
                {{#each @model.children as |child|}}
                  <li class="ai-concept-editor__child-item">
                    <LinkTo
                      @model={{child.id}}
                      @route="adminPlugins.show.discourse-ai-concepts.edit"
                    >
                      {{child.name}}
                    </LinkTo>
                    <span
                      class="ai-concept-status"
                      data-status={{child.status}}
                    >
                      {{i18n
                        (if
                          (eq child.status "active")
                          "discourse_ai.concepts.statuses.active"
                          (if
                            (eq child.status "candidate")
                            "discourse_ai.concepts.statuses.candidate"
                            "discourse_ai.concepts.statuses.retired"
                          )
                        )
                      }}
                    </span>
                  </li>
                {{/each}}
              </ul>
            </:content>
          </AdminConfigAreaCard>
        {{/if}}

        <div class="ai-concept-editor__related-row">
          <AdminConfigAreaCard
            class="ai-concept-editor__neighbors-card"
            @description="discourse_ai.concepts.neighbor_concepts_description"
            @heading="discourse_ai.concepts.neighbor_concepts"
          >
            <:content>
              {{#if this.neighborConcepts.length}}
                <ul class="ai-concept-editor__related-list">
                  {{#each this.neighborConcepts as |neighbor|}}
                    <li class="ai-concept-editor__related-item">
                      <LinkTo
                        class="ai-concept-editor__related-link"
                        @model={{neighbor.id}}
                        @route="adminPlugins.show.discourse-ai-concepts.edit"
                      >
                        {{neighbor.name}}
                      </LinkTo>
                      <span class="ai-concept-editor__related-metric">
                        {{formatSimilarity neighbor.similarity}}
                      </span>
                    </li>
                  {{/each}}
                </ul>
              {{else}}
                <p class="ai-concept-editor__empty-related">
                  {{i18n "discourse_ai.concepts.no_neighbor_concepts"}}
                </p>
              {{/if}}
            </:content>
          </AdminConfigAreaCard>

          <AdminConfigAreaCard
            class="ai-concept-editor__co-occurring-card"
            @description="discourse_ai.concepts.co_occurring_concepts_description"
            @heading="discourse_ai.concepts.co_occurring_concepts"
          >
            <:content>
              {{#if this.coOccurringConcepts.length}}
                <ul class="ai-concept-editor__related-list">
                  {{#each this.coOccurringConcepts as |related|}}
                    <li class="ai-concept-editor__related-item">
                      <LinkTo
                        class="ai-concept-editor__related-link"
                        @model={{related.id}}
                        @route="adminPlugins.show.discourse-ai-concepts.edit"
                      >
                        {{related.name}}
                      </LinkTo>
                      <span class="ai-concept-editor__related-metric">
                        {{i18n
                          "discourse_ai.concepts.shared_topics_count"
                          count=related.shared_topics_count
                        }}
                      </span>
                    </li>
                  {{/each}}
                </ul>
              {{else}}
                <p class="ai-concept-editor__empty-related">
                  {{i18n "discourse_ai.concepts.no_co_occurring_concepts"}}
                </p>
              {{/if}}
            </:content>
          </AdminConfigAreaCard>
        </div>

        <AdminConfigAreaCard
          class="ai-concept-editor__topics-card"
          @translatedDescription={{this.topicsSummary}}
          @translatedHeading={{this.taggedTopicsHeading}}
        >
          <:content>
            {{#if @model.topics.length}}
              <table class="d-table ai-concept-editor__topics-table">
                <thead class="d-table__header">
                  <tr>
                    <th>{{i18n
                        "discourse_ai.concepts.topic_columns.topic"
                      }}</th>
                    <th>
                      {{i18n "discourse_ai.concepts.topic_columns.primary"}}
                    </th>
                    <th>
                      {{i18n "discourse_ai.concepts.topic_columns.relevance"}}
                    </th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each @model.topics as |topic|}}
                    <tr class="d-table__row">
                      <td class="d-table__cell --overview">
                        <a class="d-table__overview-link" href={{topic.url}}>
                          <span class="d-table__overview-name">
                            {{topic.title}}
                          </span>
                        </a>
                        {{#if topic.concepts.length}}
                          <div class="ai-concept-editor__topic-concepts">
                            {{#each topic.concepts as |topicConcept|}}
                              {{#if (eq topicConcept.id this.concept.id)}}
                                <span class="ai-concept-pill --current">
                                  {{topicConcept.name}}
                                </span>
                              {{else}}
                                <LinkTo
                                  class="ai-concept-pill"
                                  @model={{topicConcept.id}}
                                  @route="adminPlugins.show.discourse-ai-concepts.edit"
                                >
                                  {{topicConcept.name}}
                                </LinkTo>
                              {{/if}}
                            {{/each}}
                          </div>
                        {{/if}}
                      </td>
                      <td class="d-table__cell --detail">
                        <div class="d-table__mobile-label">
                          {{i18n "discourse_ai.concepts.topic_columns.primary"}}
                        </div>
                        {{#if topic.primary}}
                          {{i18n "discourse_ai.concepts.primary_badge"}}
                        {{else}}
                          {{i18n "discourse_ai.concepts.secondary_badge"}}
                        {{/if}}
                      </td>
                      <td class="d-table__cell --detail">
                        <div class="d-table__mobile-label">
                          {{i18n
                            "discourse_ai.concepts.topic_columns.relevance"
                          }}
                        </div>
                        {{topic.relevance}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <p class="ai-concept-editor__empty-topics">
                {{i18n "discourse_ai.concepts.no_tagged_topics"}}
              </p>
            {{/if}}
          </:content>
        </AdminConfigAreaCard>
      {{/unless}}
    </div>
  </template>
}
