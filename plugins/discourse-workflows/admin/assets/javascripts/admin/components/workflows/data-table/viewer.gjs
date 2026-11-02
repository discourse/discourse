import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import AddColumnModal from "./add-column-modal.gjs";
import CellEditor from "./cell-editor.gjs";

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

// Lets CSS size the scroll box to end at the bottom of the viewport.
const measureTopOffset = modifier((element) => {
  const top = element.getBoundingClientRect().top + window.scrollY;
  element.style.setProperty("--top-offset", `${top}px`);
});

const indeterminate = modifier((element, [value]) => {
  element.indeterminate = value;
});

export default class DataTableViewer extends Component {
  @service modal;
  @service dialog;

  @tracked rows = null;
  @tracked dataTable = null;
  @tracked totalCount = 0;
  @tracked loadingMore = false;
  @tracked selectedRowIds = new Set();
  @tracked editingColumnIndex = null;
  @tracked editingName = false;

  lastClickedRowIndex = null;

  constructor() {
    super(...arguments);
    this.loadTable();
  }

  get apiBasePath() {
    return `/admin/plugins/discourse-workflows/data-tables/${this.args.dataTableId}`;
  }

  get canLoadMore() {
    return this.rows && this.rows.length < this.totalCount;
  }

  get isLoading() {
    return this.rows === null || this.dataTable === null;
  }

  @cached
  get columns() {
    return this.dataTable?.columns?.filter((c) => !c.reserved) ?? [];
  }

  get lastColumnIndex() {
    return this.columns.length - 1;
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

  async loadTable() {
    try {
      const [tableResult, rowsResult] = await Promise.all([
        ajax(`${this.apiBasePath}.json`),
        ajax(`${this.apiBasePath}/rows.json`),
      ]);
      this.dataTable = tableResult.data_table;
      this.rows = rowsResult.rows;
      this.totalCount = rowsResult.count;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(`${this.apiBasePath}/rows.json`, {
        data: { offset: this.rows.length },
      });
      this.rows = [...this.rows, ...result.rows];
      this.totalCount = result.count;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  isRowSelected(rowId) {
    return this.selectedRowIds.has(rowId);
  }

  @action
  toggleRowSelection(rowId, event) {
    const currentIndex = this.rows.findIndex((r) => r.id === rowId);
    const next = new Set(this.selectedRowIds);

    if (event?.shiftKey && this.lastClickedRowIndex !== null) {
      const from = Math.min(this.lastClickedRowIndex, currentIndex);
      const to = Math.max(this.lastClickedRowIndex, currentIndex);
      for (let i = from; i <= to; i++) {
        next.add(this.rows[i].id);
      }
    } else if (next.has(rowId)) {
      next.delete(rowId);
    } else {
      next.add(rowId);
    }

    this.lastClickedRowIndex = currentIndex;
    this.selectedRowIds = next;
  }

  @action
  clearSelection() {
    this.selectedRowIds = new Set();
    this.lastClickedRowIndex = null;
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
          await ajax(`${this.apiBasePath}/rows.json`, {
            type: "DELETE",
            data: { row_ids: [...this.selectedRowIds] },
          });
          this.selectedRowIds = new Set();
          await this.loadTable();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
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
      this.totalCount += 1;
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
  async renameColumnFromMenu(index, closeMenu) {
    await closeMenu();
    this.editingColumnIndex = index;
  }

  @action
  async moveColumn(index, offset, closeMenu) {
    await closeMenu();
    try {
      const result = await ajax(
        `${this.apiBasePath}/columns/${this.columns[index].name}/move.json`,
        { type: "PUT", data: { position: index + offset } }
      );
      this.dataTable = result.data_table;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteColumn(column, closeMenu) {
    await closeMenu();
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.data_tables.delete_column_confirm", {
        name: column.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.apiBasePath}/columns/${column.name}.json`, {
            type: "DELETE",
          });
          this.dataTable = {
            ...this.dataTable,
            columns: this.dataTable.columns.filter((c) => c !== column),
          };
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
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
      await ajax(`${this.apiBasePath}/columns/${oldName}/rename.json`, {
        type: "PATCH",
        data: { name: newName },
      });
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
          const result = await ajax(`${this.apiBasePath}/columns.json`, {
            type: "POST",
            data: { name: data.name, column_type: data.type },
          });
          this.dataTable = result.data_table;
        },
      },
    });
  }

  <template>
    <div class="workflows-data-table-viewer">
      <div class="workflows-data-table-viewer__header">
        {{#if this.editingName}}
          <input
            class="workflows-data-table-viewer__title-input"
            type="text"
            value={{this.dataTable.name}}
            {{autofocus}}
            {{on "blur" this.saveName}}
            {{on "keydown" (fn this.handleEditKeydown this.dataTable.name)}}
          />
        {{else}}
          <button
            class="workflows-data-table-viewer__title"
            type="button"
            {{on "click" this.startEditingName}}
          >{{this.dataTable.name}}</button>
        {{/if}}
        <div class="workflows-data-table-viewer__actions">
          {{#if this.hasSelection}}
            <DButton
              class="btn-danger btn-small"
              @action={{this.deleteSelectedRows}}
              @icon="trash-can"
              @label="discourse_workflows.data_tables.delete_selected"
            />
            <DButton
              class="btn-default btn-small"
              @action={{this.clearSelection}}
              @icon="xmark"
              @label="discourse_workflows.data_tables.clear_selection"
            />
          {{/if}}
        </div>
      </div>

      <DConditionalLoadingSpinner @condition={{this.isLoading}}>
        <div class="workflows-data-table-viewer__scroll" {{measureTopOffset}}>
          <DLoadMore @action={{this.loadMore}} @enabled={{this.canLoadMore}}>
            <table class="workflows-data-table-viewer__table">
              <thead>
                <tr>
                  <th class="workflows-data-table-viewer__th --id">
                    <input
                      checked={{this.allSelected}}
                      class="workflows-data-table-viewer__checkbox"
                      type="checkbox"
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
                          class="workflows-data-table-viewer__col-name-input"
                          type="text"
                          value={{col.name}}
                          {{autofocus}}
                          {{on "blur" (fn this.renameColumn index)}}
                          {{on "keydown" (fn this.handleEditKeydown col.name)}}
                        />
                      {{else}}
                        <button
                          class="workflows-data-table-viewer__col-name"
                          type="button"
                          {{on "click" (fn this.startEditingColumn index)}}
                        >{{col.name}}</button>
                      {{/if}}
                      <DMenu
                        @icon="ellipsis-vertical"
                        @identifier="workflows-data-table-column-menu"
                        @title={{i18n
                          "discourse_workflows.data_tables.column_options"
                        }}
                        @triggerClass="btn-transparent btn-small workflows-data-table-viewer__col-menu"
                      >
                        <:content as |menu|>
                          <DDropdownMenu as |dropdown|>
                            <dropdown.item>
                              <DButton
                                class="btn-transparent"
                                @action={{fn
                                  this.renameColumnFromMenu
                                  index
                                  menu.close
                                }}
                                @icon="pencil"
                                @label="discourse_workflows.data_tables.rename_column"
                              />
                            </dropdown.item>
                            {{#if (gt index 0)}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent"
                                  @action={{fn
                                    this.moveColumn
                                    index
                                    -1
                                    menu.close
                                  }}
                                  @icon="arrow-left"
                                  @label="discourse_workflows.data_tables.move_column_left"
                                />
                              </dropdown.item>
                            {{/if}}
                            {{#if (lt index this.lastColumnIndex)}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent"
                                  @action={{fn
                                    this.moveColumn
                                    index
                                    1
                                    menu.close
                                  }}
                                  @icon="arrow-right"
                                  @label="discourse_workflows.data_tables.move_column_right"
                                />
                              </dropdown.item>
                            {{/if}}
                            <dropdown.divider />
                            <dropdown.item>
                              <DButton
                                class="btn-transparent btn-danger"
                                @action={{fn this.deleteColumn col menu.close}}
                                @icon="trash-can"
                                @label="discourse_workflows.data_tables.delete_column"
                              />
                            </dropdown.item>
                          </DDropdownMenu>
                        </:content>
                      </DMenu>
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
                      class="btn-transparent btn-small"
                      @action={{this.addColumn}}
                      @icon="plus"
                    />
                  </th>
                </tr>
              </thead>
              <tbody>
                {{#each this.rows key="id" as |row|}}
                  <tr class="workflows-data-table-viewer__row">
                    <td class="workflows-data-table-viewer__cell --id">
                      <input
                        checked={{this.isRowSelected row.id}}
                        class="workflows-data-table-viewer__checkbox"
                        type="checkbox"
                        {{on "click" (fn this.toggleRowSelection row.id)}}
                      />
                      {{row.id}}
                    </td>
                    {{#each this.columns as |col|}}
                      <CellEditor
                        @column={{col}}
                        @onSave={{fn this.saveCell row}}
                        @value={{get row col.name}}
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
                      class="btn-transparent btn-small"
                      @action={{this.addRow}}
                      @icon="plus"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </DLoadMore>
          <DConditionalLoadingSpinner @condition={{this.loadingMore}} />
        </div>
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
