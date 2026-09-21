import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import { safeHttpsUrl } from "../../../lib/workflows/node-types";
import CredentialModal from "../credential/modal";
import InUseDialog from "../in-use-dialog";
import {
  nodePackDisableConfirmation,
  nodePackLifecycleUpdate,
  nodePackRemovalMessages,
} from "./lifecycle";
import NodeList from "./node-list";
import UsedByList from "./used-by-list";

const BASE_PATH = "/admin/plugins/discourse-workflows/node-packs";

export default class NodePackDetail extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service workflowsNodeTypes;

  @tracked nodePack = null;
  @tracked loadError = null;
  @tracked isUpdating = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get isLoading() {
    return !this.nodePack && !this.loadError;
  }

  get safeHomepage() {
    return safeHttpsUrl(this.nodePack?.homepage);
  }

  get singleCredentialSlot() {
    return this.nodePack?.credentials.length === 1
      ? this.nodePack.credentials[0]
      : null;
  }

  get hasMultipleCredentialSlots() {
    return this.nodePack?.credentials.length > 1;
  }

  @action
  async load() {
    this.loadError = null;
    try {
      const result = await ajax(`${BASE_PATH}/${this.args.id}.json`);
      this.nodePack = result.node_pack;
    } catch (error) {
      this.loadError = error;
      popupAjaxError(error);
    }
  }

  async update(changes) {
    this.isUpdating = true;
    try {
      const result = await ajax(`${BASE_PATH}/${this.nodePack.id}.json`, {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify(changes),
      });
      this.nodePack = result.node_pack;
      this.workflowsNodeTypes.clear();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isUpdating = false;
    }
  }

  @action
  async toggleEnabled() {
    if (this.nodePack.enabled) {
      const confirmed = await this.dialog.confirm({
        message: nodePackDisableConfirmation(),
        confirmButtonLabel: "discourse_workflows.node_packs.disable",
      });
      if (!confirmed) {
        return;
      }
    }
    await this.update(nodePackLifecycleUpdate(this.nodePack, "enabled"));
  }

  @action
  async togglePalette() {
    if (this.nodePack.palette_visible) {
      const confirmed = await this.dialog.confirm({
        message: i18n("discourse_workflows.node_packs.hide_confirm"),
        confirmButtonLabel: "discourse_workflows.node_packs.hide_from_palette",
      });
      if (!confirmed) {
        return;
      }
    }
    await this.update(
      nodePackLifecycleUpdate(this.nodePack, "palette_visible")
    );
  }

  @action
  exportPack() {
    window.open(
      `${BASE_PATH}/${this.nodePack.id}/export.json`,
      "_blank",
      "noopener"
    );
  }

  @action
  removePack() {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.node_packs.remove_confirm", {
        name: this.nodePack.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${BASE_PATH}/${this.nodePack.id}.json`, {
            type: "DELETE",
          });
          this.workflowsNodeTypes.clear();
          this.router.transitionTo(
            "adminPlugins.show.discourse-workflows-node-packs.index"
          );
        } catch (error) {
          const body = error.jqXHR?.responseJSON;
          if (body?.type === "node_pack_in_use") {
            this.showBlockedRemoval(body);
          } else {
            popupAjaxError(error);
          }
        }
      },
    });
  }

  showBlockedRemoval(body) {
    this.dialog.alert({
      title: i18n("discourse_workflows.node_packs.in_use_title"),
      bodyComponent: InUseDialog,
      bodyComponentModel: {
        description: i18n("discourse_workflows.node_packs.in_use_description"),
        workflows: body.referencing_workflows || [],
        additionalMessages: nodePackRemovalMessages(body.active_executions),
        publishedLabel: i18n("discourse_workflows.published"),
        close: () => this.dialog.cancel(),
      },
    });
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
    <DConditionalLoadingSpinner @condition={{this.isLoading}}>
      {{#if this.loadError}}
        <div
          class="alert alert-error workflows-node-packs__load-error"
          role="alert"
        >
          <p>{{i18n "discourse_workflows.node_packs.detail_load_error"}}</p>
          <DButton
            class="btn-default btn-small"
            @action={{this.load}}
            @label="discourse_workflows.node_packs.retry"
          />
        </div>
      {{else if this.nodePack}}
        <DPageSubheader @titleLabel={{this.nodePack.name}}>
          <:actions as |actions|>
            <actions.Default
              @action={{this.toggleEnabled}}
              @disabled={{this.isUpdating}}
              @icon={{if this.nodePack.enabled "pause" "play"}}
              @label={{if
                this.nodePack.enabled
                "discourse_workflows.node_packs.disable"
                "discourse_workflows.node_packs.enable"
              }}
            />
            <actions.Default
              @action={{this.togglePalette}}
              @disabled={{this.isUpdating}}
              @icon={{if this.nodePack.palette_visible "eye-slash" "eye"}}
              @label={{if
                this.nodePack.palette_visible
                "discourse_workflows.node_packs.hide_from_palette"
                "discourse_workflows.node_packs.show_in_palette"
              }}
            />
            <actions.Default
              @action={{this.exportPack}}
              @icon="download"
              @label="discourse_workflows.node_packs.export"
            />
            <actions.Danger
              @action={{this.removePack}}
              @icon="trash-can"
              @label="discourse_workflows.node_packs.remove"
            />
          </:actions>
        </DPageSubheader>

        <div class="workflows-node-packs__detail-header">
          <div class="workflows-node-packs__detail-meta">
            <span
              class="badge-notification --low"
            >v{{this.nodePack.version}}</span>
            <span class="badge-notification --low">
              {{if
                this.nodePack.enabled
                (i18n "discourse_workflows.node_packs.enabled")
                (i18n "discourse_workflows.node_packs.disabled")
              }}
            </span>
            {{#unless this.nodePack.palette_visible}}
              <span class="badge-notification --low">{{i18n
                  "discourse_workflows.node_packs.palette_hidden"
                }}</span>
            {{/unless}}
          </div>
          {{#if this.nodePack.description}}
            <p
              class="workflows-node-packs__description"
            >{{this.nodePack.description}}</p>
          {{/if}}
          {{#if this.safeHomepage}}
            <a
              href={{this.safeHomepage}}
              rel="noopener noreferrer"
              target="_blank"
            >{{i18n "discourse_workflows.node_packs.homepage"}} ↗</a>
          {{/if}}
        </div>

        <div class="workflows-node-packs__cards">
          <AdminConfigAreaCard @heading="discourse_workflows.node_packs.nodes">
            <:content>
              <NodeList @nodes={{this.nodePack.nodes}} />
            </:content>
          </AdminConfigAreaCard>

          <AdminConfigAreaCard
            @heading="discourse_workflows.node_packs.destinations"
          >
            <:content>
              <p>{{i18n
                  "discourse_workflows.node_packs.destinations_description"
                }}</p>
              <ul class="workflows-node-packs__destinations">
                {{#each this.nodePack.destinations as |origin|}}
                  <li><code>{{origin}}</code></li>
                {{/each}}
              </ul>
            </:content>
          </AdminConfigAreaCard>

          <AdminConfigAreaCard
            @heading="discourse_workflows.node_packs.credentials"
          >
            <:headerAction>
              {{#if this.singleCredentialSlot}}
                <DButton
                  class="btn-default btn-small workflows-node-packs__add-credential"
                  @action={{fn this.newCredential this.singleCredentialSlot}}
                  @icon="plus"
                  @label="discourse_workflows.credentials.add"
                />
              {{/if}}
            </:headerAction>
            <:content>
              <p>{{i18n
                  "discourse_workflows.node_packs.credentials_per_node"
                }}</p>
              {{#if this.nodePack.credentials.length}}
                <dl class="workflows-node-packs__credential-list">
                  {{#each this.nodePack.credentials as |credential|}}
                    <div>
                      <dt>{{credential.label}}</dt>
                      <dd>
                        <span>
                          {{#each
                            credential.credential_types
                            as |type index|
                          }}{{if index ", "}}{{type}}{{/each}}
                        </span>
                        {{#if this.hasMultipleCredentialSlots}}
                          <DButton
                            class="btn-default btn-small workflows-node-packs__add-credential"
                            @action={{fn this.newCredential credential}}
                            @icon="plus"
                            @label="discourse_workflows.credentials.add"
                          />
                        {{/if}}
                      </dd>
                    </div>
                  {{/each}}
                </dl>
              {{else}}
                <p>{{i18n "discourse_workflows.node_packs.no_credentials"}}</p>
              {{/if}}
            </:content>
          </AdminConfigAreaCard>

          <AdminConfigAreaCard
            @heading="discourse_workflows.node_packs.used_by"
          >
            <:content>
              <UsedByList @workflows={{this.nodePack.used_by}} />
              {{#if this.nodePack.removal.active_executions}}
                <p class="alert alert-warning">{{i18n
                    "discourse_workflows.node_packs.active_executions_blocking"
                    count=this.nodePack.removal.active_executions
                  }}</p>
              {{/if}}
            </:content>
          </AdminConfigAreaCard>
        </div>
      {{/if}}
    </DConditionalLoadingSpinner>
  </template>
}
