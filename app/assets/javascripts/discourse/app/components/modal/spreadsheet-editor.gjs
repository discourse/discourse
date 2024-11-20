import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import TextField from "discourse/components/text-field";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import {
  arrayToTable,
  findTableRegex,
  tokenRange,
} from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class SpreadsheetEditor extends Component {
  @service dialog;
  @tracked showEditReason = false;
  @tracked loading = true;
  spreadsheet = null;
  defaultColWidth = 150;
  isEditingTable = !!this.args.model.tableTokens;
  alignments = null;

  constructor() {
    super(...arguments);
    this.loadJspreadsheet();
    KeyboardShortcuts.pause();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    KeyboardShortcuts.unpause();
  }

  get modalAttributes() {
    if (this.isEditingTable) {
      return {
        title: "table_builder.edit.modal.title",
        insertTable: {
          title: "table_builder.edit.modal.create",
          icon: "pencil",
        },
      };
    } else {
      return {
        title: "table_builder.modal.title",
        insertTable: {
          title: "table_builder.modal.create",
          icon: "plus",
        },
      };
    }
  }

  @action
  createSpreadsheet(spreadsheet) {
    this.spreadsheet = spreadsheet;

    if (this.isEditingTable) {
      this.buildPopulatedTable(this.args.model.tableTokens);
    } else {
      this.buildNewTable();
    }
  }

  @action
  showEditReasonField() {
    this.showEditReason = !this.showEditReason;
  }

  @action
  interceptCloseModal() {
    if (this._hasChanges()) {
      this.dialog.yesNoConfirm({
        message: i18n("table_builder.modal.confirm_close"),
        didConfirm: () => this.args.closeModal(),
      });
    } else {
      this.args.closeModal();
    }
  }

  @action
  insertTable() {
    const updatedHeaders = this.spreadsheet
      .getHeaders()
      .split(",")
      .map((c) => c.trim()); // keys
    const updatedData = this.spreadsheet.getData(); // values
    const markdownTable = this.buildTableMarkdown(updatedHeaders, updatedData);

    if (!this.isEditingTable) {
      this.args.model.toolbarEvent.addText(markdownTable);
      return this.args.closeModal();
    } else {
      return this.updateTable(markdownTable);
    }
  }

  _hasChanges() {
    if (this.isEditingTable) {
      const originalSpreadsheetData = this.extractTableContent(
        tokenRange(this.args.model.tableTokens, "tr_open", "tr_close")
      );
      const currentHeaders = this.spreadsheet.getHeaders().split(",");
      const currentRows = this.spreadsheet.getData();
      const currentSpreadsheetData = currentHeaders.concat(currentRows.flat());

      return (
        JSON.stringify(currentSpreadsheetData) !==
        JSON.stringify(originalSpreadsheetData)
      );
    } else {
      return this.spreadsheet
        .getData()
        .flat()
        .some((element) => element !== "");
    }
  }

  async loadJspreadsheet() {
    const [jspreadsheetModule] = await Promise.all([
      import("jspreadsheet-ce"),
      import("jspreadsheet-ce/dist/jspreadsheet.css"),
      import("jsuites/dist/jsuites.css"),
    ]);

    this.jspreadsheet = jspreadsheetModule.default;
    this.loading = false;
  }

  buildNewTable() {
    const data = [
      ["", "", ""],
      ["", "", ""],
      ["", "", ""],
      ["", "", ""],
      ["", "", ""],
      ["", "", ""],
    ];

    const columns = [
      {
        title: i18n("table_builder.default_header.col_1"),
        width: this.defaultColWidth,
      },
      {
        title: i18n("table_builder.default_header.col_2"),
        width: this.defaultColWidth,
      },
      {
        title: i18n("table_builder.default_header.col_3"),

        width: this.defaultColWidth,
      },
      {
        title: i18n("table_builder.default_header.col_4"),

        width: this.defaultColWidth,
      },
    ];

    return this.buildSpreadsheet(data, columns);
  }

  extractTableContent(data) {
    return data
      .flat()
      .filter((t) => t.type === "inline")
      .map((t) => t.content);
  }

  extractTableAlignments(data) {
    return data
      .flat()
      .filter((t) => t.type === "td_open")
      .map((t) => {
        for (const attr of t.attrs?.flat() ?? []) {
          switch (attr) {
            case "text-align:left":
              return "left";
            case "text-align:center":
              return "center";
            case "text-align:right":
              return "right";
          }
        }
        return null; // default
      });
  }

  buildPopulatedTable(tableTokens) {
    const contentRows = tokenRange(tableTokens, "tr_open", "tr_close");
    const rows = [];
    let headings;
    const rowWidthFactor = 8;

    contentRows.forEach((row, index) => {
      if (index === 0) {
        // headings
        headings = this.extractTableContent(row).map((heading) => {
          return {
            title: heading || " ",
            width: Math.max(
              heading.length * rowWidthFactor,
              this.defaultColWidth
            ),
          };
        });
      } else {
        if (this.alignments == null) {
          this.alignments = this.extractTableAlignments(row);
        }
        // rows:
        rows.push(this.extractTableContent(row));
      }
    });

    headings.forEach((h, i) => {
      h.align = this.alignments?.[i] ?? "left";
    });

    return this.buildSpreadsheet(rows, headings);
  }

  buildSpreadsheet(data, columns, opts = {}) {
    const postNumber = this.args.model?.post_number;
    const exportFileName = postNumber
      ? `post-${postNumber}-table-export`
      : `post-table-export`;

    this.spreadsheet = this.jspreadsheet(this.spreadsheet, {
      data,
      columns,
      defaultColAlign: "left",
      wordWrap: true,
      csvFileName: exportFileName,
      text: this.localeMapping(),
      ...opts,
    });
  }

  buildUpdatedPost(tableIndex, raw, newRaw) {
    const tableToEdit = raw.match(findTableRegex());
    let editedTable;

    if (tableToEdit.length) {
      editedTable = raw.replace(tableToEdit[tableIndex], newRaw);
    } else {
      return raw;
    }

    // replace null characters
    editedTable = editedTable.replace(/\0/g, "\ufffd");
    return editedTable;
  }

  updateTable(markdownTable) {
    const tableIndex = this.args.model.tableIndex;
    const postId = this.args.model.post.id;
    const newRaw = markdownTable;

    const editReason =
      this.editReason || i18n("table_builder.edit.default_edit_reason");
    const raw = this.args.model.post.raw;
    const newPostRaw = this.buildUpdatedPost(tableIndex, raw, newRaw);

    return this.sendTableUpdate(postId, newPostRaw, editReason);
  }

  sendTableUpdate(postId, raw, edit_reason) {
    return ajax(`/posts/${postId}.json`, {
      type: "PUT",
      data: {
        post: {
          raw,
          edit_reason,
        },
      },
    })
      .catch(popupAjaxError)
      .finally(() => {
        this.args.closeModal();
      });
  }

  buildTableMarkdown(headers, data) {
    const table = [];
    data.forEach((row) => {
      const result = {};

      headers.forEach((_key, index) => {
        const columnKey = `col${index}`;
        return (result[columnKey] = row[index]);
      });
      table.push(result);
    });

    return arrayToTable(table, headers, "col", this.alignments);
  }

  localeMapping() {
    return {
      noRecordsFound: prefixedLocale("no_records_found"),
      show: prefixedLocale("show"),
      entries: prefixedLocale("entries"),
      insertANewColumnBefore: prefixedLocale("context_menu.col.before"),
      insertANewColumnAfter: prefixedLocale("context_menu.col.after"),
      deleteSelectedColumns: prefixedLocale("context_menu.col.delete"),
      renameThisColumn: prefixedLocale("context_menu.col.rename"),
      orderAscending: prefixedLocale("context_menu.order.ascending"),
      orderDescending: prefixedLocale("context_menu.order.descending"),
      insertANewRowBefore: prefixedLocale("context_menu.row.before"),
      insertANewRowAfter: prefixedLocale("context_menu.row.after"),
      deleteSelectedRows: prefixedLocale("context_menu.row.delete"),
      copy: prefixedLocale("context_menu.copy"),
      paste: prefixedLocale("context_menu.paste"),
      saveAs: prefixedLocale("context_menu.save"),
      about: prefixedLocale("about"),
      areYouSureToDeleteTheSelectedRows: prefixedLocale(
        "prompts.delete_selected_rows"
      ),
      areYouSureToDeleteTheSelectedColumns: prefixedLocale(
        "prompts.delete_selected_cols"
      ),
      thisActionWillDestroyAnyExistingMergedCellsAreYouSure: prefixedLocale(
        "prompts.will_destroy_merged_cells"
      ),
      thisActionWillClearYourSearchResultsAreYouSure: prefixedLocale(
        "prompts.will_clear_search_results"
      ),
      thereIsAConflictWithAnotherMergedCell: prefixedLocale(
        "prompts.conflict_with_merged_cells"
      ),
      invalidMergeProperties: prefixedLocale("invalid_merge_props"),
      cellAlreadyMerged: prefixedLocale("cells_already_merged"),
      noCellsSelected: prefixedLocale("no_cells_selected"),
    };
  }

  <template>
    <DModal
      @title={{i18n this.modalAttributes.title}}
      @closeModal={{this.interceptCloseModal}}
      class="insert-table-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <div
            {{didInsert this.createSpreadsheet}}
            tabindex="1"
            class="jexcel_container"
          ></div>
        </ConditionalLoadingSpinner>
      </:body>

      <:footer>
        {{#unless this.loading}}
          <div class="primary-actions">
            <DButton
              @label={{this.modalAttributes.insertTable.title}}
              @icon={{this.modalAttributes.insertTable.icon}}
              @action={{this.insertTable}}
              class="btn-insert-table"
            />

            <DModalCancel @close={{this.interceptCloseModal}} />
          </div>

          <div class="secondary-actions">
            {{#if this.isEditingTable}}
              <div class="edit-reason">
                <DButton
                  @icon="circle-info"
                  @title="table_builder.edit.modal.trigger_reason"
                  @action={{this.showEditReasonField}}
                  class="btn-edit-reason"
                />
                {{#if this.showEditReason}}
                  <TextField
                    @value={{this.editReason}}
                    @placeholderKey="table_builder.edit.modal.reason"
                  />
                {{/if}}
              </div>
            {{/if}}
            <DTooltip
              @icon="question"
              @triggers="click"
              @arrow={{false}}
              class="btn btn-icon no-text"
            >
              <ul>
                <h4>{{i18n "table_builder.modal.help.title"}}</h4>
                <li>
                  <kbd>
                    {{i18n "table_builder.modal.help.enter_key"}}
                  </kbd>
                  {{i18n "table_builder.modal.help.new_row"}}
                </li>
                <li>
                  <kbd>
                    {{i18n "table_builder.modal.help.tab_key"}}
                  </kbd>
                  {{i18n "table_builder.modal.help.new_col"}}
                </li>
                <li>{{i18n "table_builder.modal.help.options"}}</li>
              </ul>
            </DTooltip>
          </div>
        {{/unless}}

      </:footer>
    </DModal>
  </template>
}

function prefixedLocale(localeString) {
  return i18n(`table_builder.spreadsheet.${localeString}`);
}
