import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import humanSize from "discourse/admin/helpers/human-size";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import CrudManager from "../crud-manager";
import EmptyState from "../empty-state";
import InUseDialog from "../in-use-dialog";
import DataTableModal from "./modal";

export default class DataTablesManager extends CrudManager {
  @service router;

  get itemsKey() {
    return "data_tables";
  }

  get basePath() {
    return "/admin/plugins/discourse-workflows/data-tables";
  }

  @action
  addDataTable() {
    this.modal.show(DataTableModal, {
      model: {
        dataTable: null,
        onSave: async (data) => {
          const result = await ajax(this.apiUrl, {
            type: "POST",
            contentType: "application/json",
            data: JSON.stringify(data),
          });
          this.router.transitionTo(
            "adminPlugins.show.discourse-workflows-data-tables.show",
            result.data_table.id
          );
        },
      },
    });
  }

  @action
  async deleteDataTable(dataTable) {
    await this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.data_tables.delete_confirm"),
      didConfirm: async () => {
        try {
          await ajax(`${this.basePath}/${dataTable.id}.json`, {
            type: "DELETE",
          });
          await this.loadItems();
        } catch (e) {
          const body = e.jqXHR?.responseJSON;
          if (body?.type === "data_table_in_use") {
            this.dialog.alert({
              title: i18n("discourse_workflows.data_tables.in_use_title"),
              bodyComponent: InUseDialog,
              bodyComponentModel: {
                description: i18n(
                  "discourse_workflows.data_tables.in_use_description"
                ),
                workflows: body.referencing_workflows,
                close: () => this.dialog.cancel(),
              },
            });
          } else {
            popupAjaxError(e);
          }
        }
      },
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
          @emoji="👋"
          @title={{i18n
            "discourse_workflows.data_tables.empty_title"
            username=this.currentUser.username
          }}
          @description={{i18n
            "discourse_workflows.data_tables.empty_description"
          }}
          @buttonLabel="discourse_workflows.data_tables.add_first"
          @onAction={{this.addDataTable}}
        />
      </:empty>
      <:toolbar>
        <DButton
          @action={{this.addDataTable}}
          @label="discourse_workflows.data_tables.add"
          @icon="plus"
          class="btn-primary btn-small"
        />
      </:toolbar>
      <:head>
        <th>{{i18n "discourse_workflows.data_tables.name"}}</th>
        <th>{{i18n "discourse_workflows.data_tables.columns"}}</th>
        <th>{{i18n "discourse_workflows.data_tables.size"}}</th>
        <th></th>
      </:head>
      <:row as |dataTable|>
        <td>
          <LinkTo
            @route="adminPlugins.show.discourse-workflows-data-tables.show"
            @model={{dataTable.id}}
            class="workflows-data-tables-manager__name-link"
          >{{dataTable.name}}</LinkTo>
        </td>
        <td>{{dataTable.columns.length}}</td>
        <td>{{humanSize dataTable.size}}</td>
        <td class="workflows-admin-table__actions">
          <DButton
            @action={{fn this.deleteDataTable dataTable}}
            @icon="trash-can"
            class="btn-flat btn-small btn-danger"
          />
        </td>
      </:row>
    </AdminTable>
  </template>
}
