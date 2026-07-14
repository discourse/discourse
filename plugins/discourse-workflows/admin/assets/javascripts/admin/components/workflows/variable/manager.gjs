import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";
import PaginatedListManager from "../paginated-list-manager";
import VariableModal from "./modal";

export default class VariablesManager extends PaginatedListManager {
  @service toasts;
  @service workflowsNodeTypes;

  get collectionKey() {
    return "variables";
  }

  get basePath() {
    return "/admin/plugins/discourse-workflows/variables";
  }

  @action
  addVariable() {
    this.modal.show(VariableModal, {
      model: {
        variable: null,
        onSave: async (data) => {
          await ajax(this.apiUrl, {
            type: "POST",
            data,
          });
          this.workflowsNodeTypes.invalidateWorkflowVars();
          await this.loadItems();
        },
      },
    });
  }

  @action
  editVariable(variable) {
    this.modal.show(VariableModal, {
      model: {
        variable,
        onSave: async (data) => {
          await ajax(`${this.basePath}/${variable.id}.json`, {
            type: "PUT",
            data,
          });
          this.workflowsNodeTypes.invalidateWorkflowVars();
          await this.loadItems();
        },
      },
    });
  }

  @action
  deleteVariable(variable) {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.variables.delete_confirm", {
        key: variable.key,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.basePath}/${variable.id}.json`, {
            type: "DELETE",
          });
          this.workflowsNodeTypes.invalidateWorkflowVars();
          await this.loadItems();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async copySyntax(key) {
    await clipboardCopy(`$vars.${key}`);
    this.toasts.success({
      duration: "short",
      data: { message: i18n("discourse_workflows.variables.copied") },
    });
  }

  <template>
    <AdminTable
      @items={{this.items}}
      @isLoading={{this.isLoading}}
      @canLoadMore={{this.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loadingMore}}
    >
      <:empty>
        <EmptyState
          @emoji="wave"
          @title={{i18n
            "discourse_workflows.variables.empty_title"
            username=this.currentUser.displayName
          }}
          @description={{i18n
            "discourse_workflows.variables.empty_description"
          }}
          @buttonLabel="discourse_workflows.variables.add_first"
          @onAction={{this.addVariable}}
        />
      </:empty>
      <:toolbar>
        <DButton
          @action={{this.addVariable}}
          @label="discourse_workflows.variables.add"
          @icon="plus"
          class="btn-primary btn-small"
        />
      </:toolbar>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.variables.key"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.variables.value"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.variables.creator"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.variables.usage_syntax"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |variable|>
        <td class="d-table__cell --overview">
          <strong class="d-table__overview-name">{{variable.key}}</strong>
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.variables.value"}}
          </div>
          {{variable.value}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.variables.creator"}}
          </div>
          <a
            href={{userPath variable.created_by.username}}
            class="workflows-variables__creator"
          >
            {{dAvatar variable.created_by imageSize="tiny"}}
            <span>{{variable.created_by.username}}</span>
          </a>
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.variables.usage_syntax"}}
          </div>
          <DButton
            @action={{fn this.copySyntax variable.key}}
            @translatedLabel={{concat "$vars." variable.key}}
            @icon="copy"
            @title="discourse_workflows.variables.copy_syntax"
            class="btn-flat btn-small"
          />
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            <DButton
              @action={{fn this.editVariable variable}}
              @label="discourse_workflows.edit"
              @title="discourse_workflows.variables.edit"
              class="btn-default btn-small"
            />
            <DMenu
              @identifier="workflows-variable-menu"
              @title={{i18n "discourse_workflows.more_options"}}
              @icon="ellipsis-vertical"
              @triggerClass="btn-default"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.deleteVariable variable}}
                      @icon="trash-can"
                      @label="discourse_workflows.delete"
                      class="btn-danger"
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
