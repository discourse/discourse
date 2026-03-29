import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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
import EmptyState from "../empty-state";
import DataTableModal from "./modal";

export default class DataTablesManager extends Component {
  @service currentUser;
  @service modal;
  @service dialog;
  @service router;

  @tracked dataTables = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.loadDataTables();
  }

  async loadDataTables() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/data-tables.json"
      );
      this.dataTables = result.data_tables;
      this.loadMoreUrl = result.meta?.load_more_data_tables;
      this.totalRows =
        result.meta?.total_rows_data_tables ?? result.data_tables.length;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get isLoading() {
    return this.dataTables === null;
  }

  get canLoadMore() {
    return this.dataTables && this.dataTables.length < this.totalRows;
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || !this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(this.loadMoreUrl);
      this.dataTables = [...this.dataTables, ...result.data_tables];
      this.loadMoreUrl = result.meta?.load_more_data_tables;
      this.totalRows = result.meta?.total_rows_data_tables ?? this.totalRows;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  addDataTable() {
    this.modal.show(DataTableModal, {
      model: {
        dataTable: null,
        onSave: async (data) => {
          const result = await ajax(
            "/admin/plugins/discourse-workflows/data-tables.json",
            { type: "POST", data }
          );
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
        await ajax(
          `/admin/plugins/discourse-workflows/data-tables/${dataTable.id}.json`,
          {
            type: "DELETE",
          }
        );
        await this.loadDataTables();
      },
    });
  }

  <template>
    <AdminTable
      @items={{this.dataTables}}
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
