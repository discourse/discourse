import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ListSetting from "discourse/select-kit/components/list-setting";
import DButton from "discourse/ui-kit/d-button";

export default class WorkflowTagsEditor extends Component {
  @tracked isEditing = false;
  @tracked availableTags = [];

  #inFlight = false;
  #queued = false;
  #lastSavedTags;

  constructor() {
    super(...arguments);
    this.#lastSavedTags = [...(this.args.workflow.tags ?? [])];
    this.loadAvailableTags();
  }

  get tags() {
    return this.args.workflow.tags ?? [];
  }

  get choices() {
    return [...new Set([...this.tags, ...this.availableTags])];
  }

  async loadAvailableTags() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflow-tags.json"
      );
      this.availableTags = result.workflow_tags.map((tag) => tag.name);
    } catch {
      this.availableTags = [];
    }
  }

  @action
  startEditing() {
    this.isEditing = true;
  }

  @action
  stopEditing() {
    this.isEditing = false;
  }

  @action
  async onChange(tags) {
    this.args.workflow.set("tags", [...tags]);

    if (this.#inFlight) {
      this.#queued = true;
      return;
    }

    this.#inFlight = true;
    try {
      do {
        this.#queued = false;
        const tagsToSave = [...(this.args.workflow.tags ?? [])];
        const rollbackTo = [...this.#lastSavedTags];

        try {
          // JSON-encoded so an emptied tag list still reaches the server (form
          // encoding drops empty arrays, which would read as "not provided")
          const result = await ajax(
            `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}.json`,
            {
              type: "PUT",
              contentType: "application/json",
              data: JSON.stringify({ workflow: { tags: tagsToSave } }),
            }
          );
          this.#lastSavedTags = [...result.workflow.tags];
          if (!this.#queued) {
            this.args.workflow.set("tags", result.workflow.tags);
          }
        } catch (e) {
          popupAjaxError(e);
          if (!this.#queued) {
            this.args.workflow.set("tags", rollbackTo);
          }
        }
      } while (this.#queued);
    } finally {
      this.#inFlight = false;
    }
  }

  <template>
    <div class="workflows-tags-editor">
      {{#if this.isEditing}}
        <ListSetting
          @value={{this.tags}}
          @choices={{this.choices}}
          @onChange={{this.onChange}}
          @options={{hash
            allowAny=true
            maximum=10
            filterPlaceholder="discourse_workflows.tags.placeholder"
          }}
        />
        <DButton
          @action={{this.stopEditing}}
          @icon="check"
          @title="discourse_workflows.save"
          class="btn-flat workflows-tags-editor__done"
        />
      {{else}}
        {{#each this.tags as |tag|}}
          <span class="d-table-badge">
            <span class="d-table-badge__content">{{tag}}</span>
          </span>
        {{/each}}
        <DButton
          @action={{this.startEditing}}
          @icon="plus"
          @label="discourse_workflows.tags.manage"
          class="btn-flat workflows-tags-editor__manage"
        />
      {{/if}}
    </div>
  </template>
}
