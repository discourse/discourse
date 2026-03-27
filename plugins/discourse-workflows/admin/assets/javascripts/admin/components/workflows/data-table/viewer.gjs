import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AddColumnModal from "./add-column-modal";
import CellEditor from "./cell-editor";

const autofocus = modifier((element) => {
  element.focus();
  element.select();
  syncInputWidth(element);
  const handler = () => syncInputWidth(element);
  element.addEventListener("input", handler);
  return () => element.removeEventListener("input", handler);
});

function syncInputWidth(input) {
  input.style.setProperty("--col-name-length", input.value.length || 1);
}

const indeterminate = modifier((element, [value]) => {
  element.indeterminate = value;
});

export default class DataTableViewer extends Component {
  @service modal;
  @service dialog;
  @service router;

  @tracked rows = null;
  @tracked dataTable = null;
  @tracked selectedRowIds = new Set();
  @tracked editingColumnIndex = null;
  @tracked editingName = false;

  constructor() {
    super(...arguments);
    this.loadTable();
  }

  get apiBasePath() {
    return `/admin/plugins/discourse-workflows/data-tables/${this.args.dataTableId}`;
  }

  async loadTable() {
    try {
      const [tableResult, rowsResult] = await Promise.all([
        ajax(`${this.apiBasePath}.json`),
        ajax(`${this.apiBasePath}/rows.json`),
      ]);
      this.dataTable = tableResult.data_table;
      this.rows = rowsResult.rows;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get isLoading() {
    return this.rows === null || this.dataTable === null;
  }

  get columns() {
    return this.dataTable?.columns || [];
  }

  get hasSelection() {
    return this.selectedRowIds.size > 0;
  }

  get allSelected() {
    return (
      this.rows?.length > 0 && this.selectedRowIds.size === this.rows.length
    );
  }

  get isIndeterminate() {
    return this.hasSelection && !this.allSelected;
  }

  @action
  isRowSelected(rowId) {
    return this.selectedRowIds.has(rowId);
  }

  @action
  toggleRowSelection(rowId) {
    const next = new Set(this.selectedRowIds);
    if (next.has(rowId)) {
      next.delete(rowId);
    } else {
      next.add(rowId);
    }
    this.selectedRowIds = next;
  }

  @action
  toggleAllSelection() {
    if (this.allSelected) {
      this.selectedRowIds = new Set();
    } else {
      this.selectedRowIds = new Set(this.rows.map((r) => r.id));
    }
  }

  @action
  deleteSelectedRows() {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.data_tables.delete_rows_confirm", {
        count: this.selectedRowIds.size,
      }),
      didConfirm: async () => {
        try {
          const ids = [...this.selectedRowIds];
          await Promise.all(
            ids.map((id) =>
              ajax(`${this.apiBasePath}/rows/${id}.json`, { type: "DELETE" })
            )
          );
          this.selectedRowIds = new Set();
          await this.loadTable();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  goBack() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows-data-tables"
    );
  }

  @action
  async saveCell(row, columnName, value) {
    try {
      const result = await ajax(`${this.apiBasePath}/rows/${row.id}.json`, {
        type: "PUT",
        data: { data: { [columnName]: value } },
      });
      const idx = this.rows.findIndex((r) => r.id === row.id);
      if (idx !== -1) {
        const updated = [...this.rows];
        updated[idx] = result.row;
        this.rows = updated;
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async addRow() {
    try {
      const result = await ajax(`${this.apiBasePath}/rows.json`, {
        type: "POST",
        data: { data: {} },
      });
      this.rows = [...this.rows, result.row];
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  startEditingName() {
    this.editingName = true;
  }

  @action
  handleEditKeydown(originalValue, event) {
    if (event.key === "Enter") {
      event.target.blur();
    } else if (event.key === "Escape") {
      event.target.value = originalValue;
      event.target.blur();
    }
  }

  @action
  async saveName(event) {
    this.editingName = false;
    const newName = event.target.value.trim();
    if (!newName || newName === this.dataTable.name) {
      return;
    }
    try {
      const result = await ajax(`${this.apiBasePath}.json`, {
        type: "PUT",
        data: { name: newName },
      });
      this.dataTable = result.data_table;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  startEditingColumn(index) {
    this.editingColumnIndex = index;
  }

  @action
  async renameColumn(index, event) {
    this.editingColumnIndex = null;
    const newName = event.target.value.trim();
    const oldName = this.columns[index].name;
    if (!newName || newName === oldName) {
      return;
    }
    try {
      const newColumns = this.columns.map((col, i) =>
        i === index ? { ...col, name: newName } : col
      );
      const result = await ajax(`${this.apiBasePath}.json`, {
        type: "PUT",
        data: { columns: newColumns },
      });
      this.dataTable = result.data_table;
      await this.loadTable();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  addColumn() {
    this.modal.show(AddColumnModal, {
      model: {
        onSave: async (data) => {
          try {
            const newColumns = [
              ...this.columns,
              { name: data.name, type: data.type },
            ];
            const result = await ajax(`${this.apiBasePath}.json`, {
              type: "PUT",
              data: { columns: newColumns },
            });
            this.dataTable = result.data_table;
          } catch (e) {
            popupAjaxError(e);
          }
        },
      },
    });
  }

  <template>
    <div class="workflows-data-table-viewer">
      <div class="workflows-data-table-viewer__header">
        <DButton
          @action={{this.goBack}}
          @icon="chevron-left"
          @label="discourse_workflows.data_tables.back"
          class="btn-flat"
        />
        {{#if this.editingName}}
          <input
            type="text"
            value={{this.dataTable.name}}
            class="workflows-data-table-viewer__title-input"
            {{autofocus}}
            {{on "blur" this.saveName}}
            {{on "keydown" (fn this.handleEditKeydown this.dataTable.name)}}
          />
        {{else}}
          {{! template-lint-disable no-nested-interactive }}
          <button
            type="button"
            class="workflows-data-table-viewer__title"
            {{on "click" this.startEditingName}}
          >{{this.dataTable.name}}</button>
        {{/if}}
        <div class="workflows-data-table-viewer__actions">
          {{#if this.hasSelection}}
            <DButton
              @action={{this.deleteSelectedRows}}
              @icon="trash-can"
              @label="discourse_workflows.data_tables.delete_selected"
              class="btn-danger btn-small"
            />
          {{/if}}
        </div>
      </div>

      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        <div class="workflows-data-table-viewer__scroll">
          <table class="workflows-data-table-viewer__table">
            <thead>
              <tr>
                <th class="workflows-data-table-viewer__th --id">
                  <input
                    type="checkbox"
                    checked={{this.allSelected}}
                    class="workflows-data-table-viewer__checkbox"
                    {{indeterminate this.isIndeterminate}}
                    {{on "change" this.toggleAllSelection}}
                  />
                  id
                </th>
                {{#each this.columns as |col index|}}
                  <th class="workflows-data-table-viewer__th">
                    <span
                      class="workflows-data-table-viewer__col-type"
                    >{{col.type}}</span>
                    {{#if (eq this.editingColumnIndex index)}}
                      <input
                        type="text"
                        value={{col.name}}
                        class="workflows-data-table-viewer__col-name-input"
                        {{autofocus}}
                        {{on "blur" (fn this.renameColumn index)}}
                        {{on "keydown" (fn this.handleEditKeydown col.name)}}
                      />
                    {{else}}
                      {{! template-lint-disable no-nested-interactive }}
                      <button
                        type="button"
                        class="workflows-data-table-viewer__col-name"
                        {{on "click" (fn this.startEditingColumn index)}}
                      >{{col.name}}</button>
                    {{/if}}
                  </th>
                {{/each}}
                <th
                  class="workflows-data-table-viewer__th --system"
                >created_at</th>
                <th
                  class="workflows-data-table-viewer__th --system"
                >updated_at</th>
                <th class="workflows-data-table-viewer__th --add-column">
                  <DButton
                    @action={{this.addColumn}}
                    @icon="plus"
                    class="btn-transparent btn-small"
                  />
                </th>
              </tr>
            </thead>
            <tbody>
              {{#each this.rows as |row|}}
                <tr class="workflows-data-table-viewer__row">
                  <td class="workflows-data-table-viewer__cell --id">
                    <input
                      type="checkbox"
                      checked={{this.isRowSelected row.id}}
                      class="workflows-data-table-viewer__checkbox"
                      {{on "change" (fn this.toggleRowSelection row.id)}}
                    />
                    {{row.id}}
                  </td>
                  {{#each this.columns as |col|}}
                    <CellEditor
                      @column={{col}}
                      @value={{get row col.name}}
                      @onSave={{fn this.saveCell row}}
                    />
                  {{/each}}
                  <td
                    class="workflows-data-table-viewer__cell --system"
                  >{{row.created_at}}</td>
                  <td
                    class="workflows-data-table-viewer__cell --system"
                  >{{row.updated_at}}</td>
                  <td class="--add-column"></td>
                </tr>
              {{/each}}
              <tr class="workflows-data-table-viewer__add-row">
                <td colspan="99">
                  <DButton
                    @action={{this.addRow}}
                    @icon="plus"
                    class="btn-transparent btn-small"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
