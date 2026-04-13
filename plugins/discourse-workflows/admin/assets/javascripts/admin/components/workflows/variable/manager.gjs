import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import CrudManager from "../crud-manager";
import EmptyState from "../empty-state";
import VariableModal from "./modal";

export default class VariablesManager extends CrudManager {
  @service workflowsNodeTypes;

  get itemsKey() {
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
          @emoji="👋"
          @title={{i18n
            "discourse_workflows.variables.empty_title"
            username=this.currentUser.username
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
        <th>{{i18n "discourse_workflows.variables.key"}}</th>
        <th>{{i18n "discourse_workflows.variables.value"}}</th>
        <th>{{i18n "discourse_workflows.variables.usage_syntax"}}</th>
        <th></th>
      </:head>
      <:row as |variable|>
        <td>{{variable.key}}</td>
        <td>{{variable.value}}</td>
        <td>
          <DButton
            @action={{fn this.copySyntax variable.key}}
            @translatedLabel={{concat "$vars." variable.key}}
            @icon="copy"
            @title="discourse_workflows.variables.copy_syntax"
            class="btn-flat btn-small"
          />
        </td>
        <td class="workflows-admin-table__actions">
          <DButton
            @action={{fn this.editVariable variable}}
            @icon="pencil"
            class="btn-flat btn-small"
          />
          <DButton
            @action={{fn this.deleteVariable variable}}
            @icon="trash-can"
            class="btn-flat btn-small btn-danger"
          />
        </td>
      </:row>
    </AdminTable>
  </template>
}
