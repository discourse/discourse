import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CredentialModal from "../credential/modal";

const BASE_PATH = "/admin/plugins/discourse-workflows/node-packs";

export default class NodePackImportModal extends Component {
  @service modal;
  @service router;
  @service toasts;
  @service workflowsNodeTypes;

  @tracked manifestText = "";
  @tracked selectedFilename = null;
  @tracked preview = null;
  @tracked validationErrors = [];
  @tracked requestError = null;
  @tracked approvedDestinations = new Set();
  @tracked isPreviewing = false;
  @tracked isInstalling = false;

  get chooseFormData() {
    return { manifest: this.manifestText };
  }

  get approvalFormData() {
    return Object.fromEntries(
      (this.preview?.destinations || []).map((origin, index) => [
        `destination_${index}`,
        this.approvedDestinations.has(origin),
      ])
    );
  }

  get allDestinationsApproved() {
    return (
      this.preview?.destinations.length > 0 &&
      this.preview.destinations.every((origin) =>
        this.approvedDestinations.has(origin)
      )
    );
  }

  get isUpdate() {
    return this.preview?.change !== "install";
  }

  get destinationSummary() {
    return (this.preview?.destinations || []).join(", ");
  }

  get singleCredentialSlot() {
    return this.preview?.credentials.length === 1
      ? this.preview.credentials[0]
      : null;
  }

  get hasMultipleCredentialSlots() {
    return this.preview?.credentials.length > 1;
  }

  get installLabel() {
    if (this.isUpdate) {
      return i18n("discourse_workflows.node_packs.update_to", {
        version: this.preview.manifest.version,
      });
    }

    return i18n("discourse_workflows.node_packs.install_nodes", {
      count: this.preview.nodes.filter((node) => node.change !== "dropped")
        .length,
    });
  }

  get requestErrorMessage() {
    if (!this.requestError) {
      return null;
    }

    const details = this.requestError.errors
      ?.map((error) => error.message)
      .join(" ");
    if (details) {
      return details;
    }

    const messages = {
      definition_conflict:
        "discourse_workflows.node_packs.errors.definition_conflict",
      destinations_not_approved:
        "discourse_workflows.node_packs.errors.destinations_not_approved",
      downgrade_not_allowed:
        "discourse_workflows.node_packs.errors.downgrade_not_allowed",
      revision_conflict:
        "discourse_workflows.node_packs.errors.revision_conflict",
    };
    return i18n(
      messages[this.requestError.type] ||
        "discourse_workflows.node_packs.errors.unknown"
    );
  }

  @action
  async chooseFile(files) {
    const file = files?.[0];
    if (!file) {
      return;
    }

    try {
      this.manifestText = await file.text();
      this.selectedFilename = file.name;
      this.validationErrors = [];
      this.requestError = null;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async previewManifest(data) {
    const manifest = data.manifest?.trim();
    if (!manifest) {
      this.validationErrors = [
        {
          path: "manifest",
          message: i18n("discourse_workflows.node_packs.manifest_required"),
        },
      ];
      return;
    }

    this.isPreviewing = true;
    this.validationErrors = [];
    this.requestError = null;
    try {
      const result = await ajax(`${BASE_PATH}/preview.json`, {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({ manifest }),
      });
      this.manifestText = manifest;
      this.preview = result.preview;
      this.approvedDestinations = new Set(
        result.preview.previously_approved_destinations || []
      );
    } catch (error) {
      const body = error.jqXHR?.responseJSON;
      if (body?.type === "invalid_manifest") {
        this.validationErrors = body.errors || [];
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.isPreviewing = false;
    }
  }

  @action
  backToChoose() {
    this.preview = null;
    this.requestError = null;
  }

  @action
  handleApprovalSet(origin, value) {
    const approvedDestinations = new Set(this.approvedDestinations);
    if (value) {
      approvedDestinations.add(origin);
    } else {
      approvedDestinations.delete(origin);
    }
    this.approvedDestinations = approvedDestinations;
  }

  @action
  async install(data) {
    const approvedDestinations = this.preview.destinations.filter(
      (_origin, index) => data[`destination_${index}`] === true
    );

    if (approvedDestinations.length !== this.preview.destinations.length) {
      this.requestError = { type: "destinations_not_approved" };
      return;
    }

    this.isInstalling = true;
    this.requestError = null;
    try {
      const result = await ajax(`${BASE_PATH}.json`, {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({
          manifest: this.manifestText,
          approved_destinations: approvedDestinations,
        }),
      });
      this.workflowsNodeTypes.clear();
      this.toasts.success({
        data: {
          message: i18n(
            result.result === "updated"
              ? "discourse_workflows.node_packs.updated"
              : result.result === "unchanged"
                ? "discourse_workflows.node_packs.unchanged"
                : "discourse_workflows.node_packs.installed"
          ),
        },
      });
      this.args.model.onSuccess?.(result.node_pack);
      this.args.closeModal();
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows-node-packs.show",
        result.node_pack.id
      );
    } catch (error) {
      const body = error.jqXHR?.responseJSON;
      if (body?.type) {
        this.requestError = body;
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.isInstalling = false;
    }
  }

  @action
  newCredential(credentialSlot) {
    this.modal.show(CredentialModal, {
      model: {
        credential: null,
        credentialSlot: {
          ...credentialSlot,
          name: credentialSlot.name || credentialSlot.key,
        },
        onSave: async (data) => {
          await ajax("/admin/plugins/discourse-workflows/credentials.json", {
            type: "POST",
            data,
          });
        },
      },
    });
  }

  <template>
    <DModal
      class="workflows-node-pack-import"
      @closeModal={{@closeModal}}
      @inline={{@model.inline}}
      @title={{i18n "discourse_workflows.node_packs.import_title"}}
    >
      <:body>
        {{#if this.preview}}
          <div class="workflows-node-pack-import__pack-header">
            <span class="workflows-node-pack-import__pack-icon">
              {{dIcon (or this.preview.manifest.icon "cubes")}}
            </span>
            <div>
              <h3>{{this.preview.manifest.name}}</h3>
              <span>{{i18n
                  "discourse_workflows.node_packs.review_summary"
                  version=this.preview.manifest.version
                  count=this.preview.nodes.length
                }}</span>
            </div>
          </div>

          {{#if this.preview.manifest.description}}
            <p>{{this.preview.manifest.description}}</p>
          {{/if}}

          <div class="workflows-node-pack-import__nodes">
            {{#each this.preview.nodes as |node|}}
              <article class="workflows-node-pack-import__node">
                <span class="workflows-node-pack-import__node-icon">
                  {{dIcon (or node.icon this.preview.manifest.icon "cubes")}}
                </span>
                <div>
                  <strong>{{node.label}}</strong>
                  {{#if node.subtitle}}<span>{{node.subtitle}}</span>{{/if}}
                </div>
                <span class="badge-notification --low">{{i18n
                    (concat
                      "discourse_workflows.node_packs.changes." node.change
                    )
                  }}</span>
              </article>
            {{/each}}
          </div>

          <AdminConfigAreaCard
            class="workflows-node-pack-import__capabilities"
            @heading="discourse_workflows.node_packs.what_it_can_do"
          >
            <:content>
              <p>{{i18n
                  "discourse_workflows.node_packs.mapped_data_only"
                  origins=this.destinationSummary
                }}</p>
              <p>{{i18n "discourse_workflows.node_packs.no_custom_code"}}</p>
            </:content>
          </AdminConfigAreaCard>

          {{#if this.preview.credentials.length}}
            <section class="workflows-node-pack-import__credentials">
              <div class="workflows-node-pack-import__section-header">
                <h3>{{i18n
                    "discourse_workflows.node_packs.credentials_required"
                  }}</h3>
                {{#if this.singleCredentialSlot}}
                  <DButton
                    class="btn-default btn-small workflows-node-pack-import__add-credential"
                    @action={{fn this.newCredential this.singleCredentialSlot}}
                    @icon="plus"
                    @label="discourse_workflows.credentials.add"
                  />
                {{/if}}
              </div>
              <ul>
                {{#each this.preview.credentials as |credential|}}
                  <li>
                    <strong>{{credential.label}}</strong>
                    <span>
                      {{#each credential.credential_types as |type index|}}{{if
                          index
                          ", "
                        }}{{type}}{{/each}}
                    </span>
                    {{#if this.hasMultipleCredentialSlots}}
                      <DButton
                        class="btn-default btn-small workflows-node-pack-import__add-credential"
                        @action={{fn this.newCredential credential}}
                        @icon="plus"
                        @label="discourse_workflows.credentials.add"
                      />
                    {{/if}}
                  </li>
                {{/each}}
              </ul>
              <p class="workflows-node-pack-import__hint">{{i18n
                  "discourse_workflows.node_packs.credentials_per_node"
                }}</p>
            </section>
          {{/if}}

          <Form
            class="workflows-node-pack-import__approval-form"
            @data={{this.approvalFormData}}
            @onSubmit={{this.install}}
            as |form|
          >
            <form.CheckboxGroup
              @description={{i18n
                "discourse_workflows.node_packs.approve_destination_description"
              }}
              @title={{i18n
                "discourse_workflows.node_packs.approve_destination"
              }}
              as |group|
            >
              {{#each this.preview.destinations as |origin index|}}
                <group.Field
                  @name={{concat "destination_" index}}
                  @onSet={{fn this.handleApprovalSet origin}}
                  @title={{origin}}
                  @type="checkbox"
                  @validation="accepted"
                  as |field|
                >
                  <field.Control />
                </group.Field>
              {{/each}}
            </form.CheckboxGroup>

            {{#each this.preview.warnings as |warning|}}
              <div class="alert alert-warning">{{warning}}</div>
            {{/each}}
            {{#if this.requestErrorMessage}}
              <div class="alert alert-error" role="alert">
                {{this.requestErrorMessage}}
              </div>
            {{/if}}

            <div class="workflows-node-pack-import__actions">
              <DButton
                class="btn-default"
                @action={{this.backToChoose}}
                @label="discourse_workflows.node_packs.back"
              />
              <DButton
                class="btn-primary form-kit__button"
                type="submit"
                @disabled={{or
                  this.isInstalling
                  (not this.allDestinationsApproved)
                }}
                @translatedLabel={{this.installLabel}}
              />
            </div>
          </Form>
        {{else}}
          <Form
            class="workflows-node-pack-import__choose-form"
            @data={{this.chooseFormData}}
            @onSubmit={{this.previewManifest}}
            as |form|
          >
            <div class="workflows-node-pack-import__file-row">
              <DPickFilesButton
                @acceptedFormatsOverride=".json,application/json"
                @fileInputClass="hidden-upload-field"
                @icon="upload"
                @label="discourse_workflows.node_packs.choose_file"
                @onFilesPicked={{this.chooseFile}}
                @showButton={{true}}
              />
              {{#if this.selectedFilename}}
                <span>{{this.selectedFilename}}</span>
              {{/if}}
            </div>

            <div class="workflows-node-pack-import__separator">
              {{i18n "discourse_workflows.node_packs.or_paste"}}
            </div>

            <form.Field
              @format="full"
              @name="manifest"
              @title={{i18n "discourse_workflows.node_packs.manifest"}}
              @type="textarea"
              as |field|
            >
              <field.Control
                placeholder={{i18n
                  "discourse_workflows.node_packs.manifest_placeholder"
                }}
                rows="12"
              />
            </form.Field>

            {{#if this.validationErrors.length}}
              <div class="alert alert-error" role="alert">
                <strong>{{i18n
                    "discourse_workflows.node_packs.validation_errors"
                  }}</strong>
                <ul>
                  {{#each this.validationErrors as |error|}}
                    <li><code>{{error.path}}</code> — {{error.message}}</li>
                  {{/each}}
                </ul>
              </div>
            {{/if}}

            <form.Submit
              @disabled={{this.isPreviewing}}
              @label="discourse_workflows.node_packs.preview"
            />
          </Form>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
