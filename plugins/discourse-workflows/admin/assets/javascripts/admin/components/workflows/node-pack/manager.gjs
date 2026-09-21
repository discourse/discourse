import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";
import InUseDialog from "../in-use-dialog";
import PaginatedListManager from "../paginated-list-manager";
import NodePackImportModal from "./import-modal";
import {
  nodePackDisableConfirmation,
  nodePackLifecycleUpdate,
  nodePackRemovalMessages,
} from "./lifecycle";

export default class NodePackManager extends PaginatedListManager {
  @service workflowsNodeTypes;

  get collectionKey() {
    return "node_packs";
  }

  get basePath() {
    return "/admin/plugins/discourse-workflows/node-packs";
  }

  @action
  importPack() {
    this.modal.show(NodePackImportModal, {
      model: {
        onSuccess: () => this.loadItems(),
      },
    });
  }

  async updatePack(nodePack, changes) {
    try {
      const result = await ajax(`${this.basePath}/${nodePack.id}.json`, {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify(changes),
      });
      this.workflowsNodeTypes.clear();
      this.items = this.items.map((item) =>
        item.id === nodePack.id ? result.node_pack : item
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async toggleEnabled(nodePack) {
    if (nodePack.enabled) {
      const confirmed = await this.dialog.confirm({
        message: nodePackDisableConfirmation(),
        confirmButtonLabel: "discourse_workflows.node_packs.disable",
      });
      if (!confirmed) {
        return;
      }
    }
    await this.updatePack(
      nodePack,
      nodePackLifecycleUpdate(nodePack, "enabled")
    );
  }

  @action
  async togglePalette(nodePack) {
    if (nodePack.palette_visible) {
      const confirmed = await this.dialog.confirm({
        message: i18n("discourse_workflows.node_packs.hide_confirm"),
        confirmButtonLabel: "discourse_workflows.node_packs.hide_from_palette",
      });
      if (!confirmed) {
        return;
      }
    }
    await this.updatePack(
      nodePack,
      nodePackLifecycleUpdate(nodePack, "palette_visible")
    );
  }

  @action
  exportPack(nodePack) {
    window.open(
      `${this.basePath}/${nodePack.id}/export.json`,
      "_blank",
      "noopener"
    );
  }

  @action
  deletePack(nodePack) {
    return this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.node_packs.remove_confirm", {
        name: nodePack.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.basePath}/${nodePack.id}.json`, {
            type: "DELETE",
          });
          this.workflowsNodeTypes.clear();
          await this.loadItems();
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

  <template>
    <AdminTable
      @canLoadMore={{this.canLoadMore}}
      @isLoading={{this.isLoading}}
      @items={{this.items}}
      @loadingMore={{this.loadingMore}}
      @loadMore={{this.loadMore}}
    >
      <:empty>
        {{#if this.loadError}}
          <div
            class="alert alert-error workflows-node-packs__load-error"
            role="alert"
          >
            <p>{{i18n "discourse_workflows.node_packs.load_error"}}</p>
            <DButton
              class="btn-default btn-small"
              @action={{this.loadItems}}
              @label="discourse_workflows.node_packs.retry"
            />
          </div>
        {{else}}
          <EmptyState
            @buttonIcon="upload"
            @buttonLabel="discourse_workflows.node_packs.import"
            @description={{i18n
              "discourse_workflows.node_packs.empty_description"
            }}
            @emoji="package"
            @onAction={{this.importPack}}
            @title={{i18n "discourse_workflows.node_packs.empty_title"}}
          />
        {{/if}}
      </:empty>
      <:toolbar>
        <DButton
          class="btn-primary btn-small"
          @action={{this.importPack}}
          @icon="upload"
          @label="discourse_workflows.node_packs.import"
        />
      </:toolbar>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.name"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.version"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.nodes"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.used_by"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.status"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.node_packs.updated_at"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |nodePack|>
        <td class="d-table__cell --overview">
          <LinkTo
            class="d-table__overview-link workflows-node-packs__pack-link"
            @model={{nodePack.id}}
            @route="adminPlugins.show.discourse-workflows-node-packs.show"
          >
            <span class="workflows-node-packs__pack-icon">{{dIcon
                (or nodePack.icon "cubes")
              }}</span>
            <span>
              <strong class="d-table__overview-name">{{nodePack.name}}</strong>
              <span
                class="workflows-node-packs__secondary"
              >{{nodePack.key}}</span>
            </span>
          </LinkTo>
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">{{i18n
              "discourse_workflows.node_packs.version"
            }}</div>
          v{{nodePack.version}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">{{i18n
              "discourse_workflows.node_packs.nodes"
            }}</div>
          {{i18n
            "discourse_workflows.node_packs.nodes_summary"
            active=nodePack.node_count
            retired=nodePack.retired_count
          }}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">{{i18n
              "discourse_workflows.node_packs.used_by"
            }}</div>
          <LinkTo
            @model={{nodePack.id}}
            @route="adminPlugins.show.discourse-workflows-node-packs.show"
          >{{nodePack.used_by_count}}</LinkTo>
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">{{i18n
              "discourse_workflows.node_packs.status"
            }}</div>
          <span class="badge-notification --low">
            {{if
              nodePack.enabled
              (i18n "discourse_workflows.node_packs.enabled")
              (i18n "discourse_workflows.node_packs.disabled")
            }}
          </span>
          {{#unless nodePack.palette_visible}}
            <span class="badge-notification --low">
              {{i18n "discourse_workflows.node_packs.palette_hidden"}}
            </span>
          {{/unless}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">{{i18n
              "discourse_workflows.node_packs.updated_at"
            }}</div>
          {{dFormatDate nodePack.updated_at format="medium"}}
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            <DButton
              class="btn-default btn-small"
              @label="discourse_workflows.node_packs.view"
              @route="adminPlugins.show.discourse-workflows-node-packs.show"
              @routeModels={{array nodePack.id}}
            />
            <DMenu
              @icon="ellipsis-vertical"
              @identifier="workflows-node-pack-menu"
              @title={{i18n "discourse_workflows.more_options"}}
              @triggerClass="btn-default"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.toggleEnabled nodePack}}
                      @icon={{if nodePack.enabled "pause" "play"}}
                      @label={{if
                        nodePack.enabled
                        "discourse_workflows.node_packs.disable"
                        "discourse_workflows.node_packs.enable"
                      }}
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.togglePalette nodePack}}
                      @icon={{if nodePack.palette_visible "eye-slash" "eye"}}
                      @label={{if
                        nodePack.palette_visible
                        "discourse_workflows.node_packs.hide_from_palette"
                        "discourse_workflows.node_packs.show_in_palette"
                      }}
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.exportPack nodePack}}
                      @icon="download"
                      @label="discourse_workflows.node_packs.export"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      class="btn-danger"
                      @action={{fn this.deletePack nodePack}}
                      @icon="trash-can"
                      @label="discourse_workflows.node_packs.remove"
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </:content>
            </DMenu>
          </div>
        </td>
      </:row>
    </AdminTable>
  </template>
}
