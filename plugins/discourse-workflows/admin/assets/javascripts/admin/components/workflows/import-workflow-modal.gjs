import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import DTextarea from "discourse/ui-kit/d-textarea";
import { i18n } from "discourse-i18n";
import { buildWorkflowFromJson } from "../../lib/workflows/import-validator.js";
import { resolveNodeTypeVersion } from "../../lib/workflows/node-types.js";
import { STICKY_NOTE_TYPE } from "../../models/sticky-note.js";

export default class ImportWorkflowModal extends Component {
  @service workflowsNodeTypes;

  @tracked jsonText = "";
  @tracked workflowName = "";
  @tracked fileName = null;
  @tracked errors = [];
  @tracked importing = false;

  acceptedFormats = [".json", "application/json"];

  #fileInput = null;

  get canImport() {
    return this.jsonText.trim() !== "" && !this.importing;
  }

  get cannotImport() {
    return !this.canImport;
  }

  @action
  registerFileInput(input) {
    this.#fileInput = input;
  }

  @action
  async onFilesPicked(files) {
    const file = files[0];
    if (!file) {
      return;
    }

    try {
      this.jsonText = await file.text();
      this.fileName = file.name;
      this.errors = [];
    } catch {
      this.errors = [
        i18n("discourse_workflows.import_workflow.file_read_error"),
      ];
    } finally {
      // reset the input so re-picking the same file fires change again
      if (this.#fileInput) {
        this.#fileInput.value = "";
      }
    }
  }

  @action
  updateJsonText(event) {
    this.jsonText = event.target.value;
    this.fileName = null;
    this.errors = [];
  }

  @action
  updateWorkflowName(event) {
    this.workflowName = event.target.value;
    this.errors = [];
  }

  @action
  async importWorkflow() {
    if (!this.canImport) {
      return;
    }

    this.importing = true;
    this.errors = [];
    try {
      const { workflow, errors } = buildWorkflowFromJson(this.jsonText, {
        name: this.workflowName,
      });
      this.errors = errors;
      if (!workflow) {
        return;
      }

      workflow.name = workflow.name.trim();
      this.errors = await this.#checkNodeTypeAvailability(workflow);
      if (this.errors.length) {
        return;
      }

      await this.args.model.onImport(workflow);
      this.args.closeModal();
    } catch (error) {
      this.errors = [this.#ajaxErrorMessage(error)];
    } finally {
      this.importing = false;
    }
  }

  async #checkNodeTypeAvailability(workflow) {
    if (this.workflowsNodeTypes.nodeTypes === null) {
      await this.workflowsNodeTypes.load();
    }

    const errors = [];
    for (const node of workflow.nodes || []) {
      // sticky notes are canvas decorations, not node types, so they never
      // exist in the node registry and must not fail the availability check
      if (node.type === STICKY_NOTE_TYPE) {
        continue;
      }

      const nodeType = this.workflowsNodeTypes.findNodeType(node.type);
      if (!nodeType) {
        errors.push(
          i18n("discourse_workflows.import_workflow.unknown_node_type", {
            name: node.name,
            type: node.type,
          })
        );
        continue;
      }

      const version = resolveNodeTypeVersion(nodeType, node.typeVersion);
      if (!version?.available) {
        errors.push(
          i18n("discourse_workflows.import_workflow.node_type_unavailable", {
            name: node.name,
            type: node.type,
          })
        );
      }
    }

    return errors;
  }

  #ajaxErrorMessage(error) {
    const status = error?.jqXHR?.status ?? error?.status;
    if (status >= 500) {
      return i18n("discourse_workflows.import_workflow.unexpected_error");
    }

    return (
      error?.jqXHR?.responseJSON?.errors?.join("\n") ||
      error?.jqXHR?.responseJSON?.error ||
      error?.jqXHR?.responseText ||
      i18n("discourse_workflows.import_workflow.unexpected_error")
    );
  }

  <template>
    <DModal
      class="import-workflow-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_workflows.import_workflow.title"}}
    >
      <:body>
        <div class="import-workflow-modal__form">
          <label for="import-workflow-name">
            {{i18n "discourse_workflows.import_workflow.name_label"}}
          </label>
          <Input
            class="input-xxlarge"
            id="import-workflow-name"
            placeholder={{i18n
              "discourse_workflows.import_workflow.name_placeholder"
            }}
            @value={{this.workflowName}}
            {{on "input" this.updateWorkflowName}}
          />

          <div class="import-workflow-modal__json-header">
            <label for="import-workflow-json">
              {{i18n "discourse_workflows.import_workflow.json_label"}}
            </label>
            <DPickFilesButton
              class="import-workflow-modal__select-file-btn"
              @acceptedFormatsOverride={{this.acceptedFormats}}
              @icon="upload"
              @label="discourse_workflows.import_workflow.select_file"
              @onFilesPicked={{this.onFilesPicked}}
              @registerFileInput={{this.registerFileInput}}
              @showButton={{true}}
            />
          </div>
          {{#if this.fileName}}
            <div class="import-workflow-modal__file-name">
              {{i18n
                "discourse_workflows.import_workflow.selected_file"
                fileName=this.fileName
              }}
            </div>
          {{/if}}
          <DTextarea
            class="import-workflow-modal__json"
            id="import-workflow-json"
            placeholder={{i18n
              "discourse_workflows.import_workflow.json_placeholder"
            }}
            @value={{this.jsonText}}
            {{on "input" this.updateJsonText}}
          />

          {{#if this.errors.length}}
            <div class="alert alert-error import-workflow-modal__errors">
              <ul>
                {{#each this.errors as |err|}}
                  <li>{{err}}</li>
                {{/each}}
              </ul>
            </div>
          {{/if}}

          <div class="import-workflow-modal__actions">
            <DButton
              class="btn-primary"
              @action={{this.importWorkflow}}
              @disabled={{this.cannotImport}}
              @isLoading={{this.importing}}
              @translatedLabel={{i18n
                "discourse_workflows.import_workflow.submit"
              }}
            />
            <DButton
              class="btn-default"
              @action={{@closeModal}}
              @translatedLabel={{i18n "cancel"}}
            />
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
