import NodeMenu from "discourse/components/composer/node-menu";
import { i18n } from "discourse-i18n";
import {
  addColumn,
  addRow,
  ALIGNMENTS,
  clearCellContents,
  columnAlignment,
  currentCell,
  deleteColumn,
  deleteRow,
  deleteTable,
  duplicateColumn,
  duplicateRow,
  moveColumn,
  moveRow,
  setColumnAlignment,
} from "./commands";
import { cellTarget, columnTarget, rowTarget } from "./grid";

/** Identifier of the menu shown from a table grip. */
export const TABLE_MENU_IDENTIFIER = "composer-table-menu";

const ALIGNMENT_ICONS = {
  left: "align-left",
  center: "align-center",
  right: "align-right",
};

let triggerSequence = 0;

export async function openGripMenu({ kind, view, pluginParams, grip }, target) {
  if (!view.editable) {
    return;
  }

  const items =
    kind === "row" ? rowMenuItems(view, target) : columnMenuItems(view, target);

  await showMenu(pluginParams, view, grip, items, {
    placement: kind === "row" ? "right-start" : "bottom-start",
  });
}

async function showMenu(pluginParams, view, trigger, items, options) {
  if (!view.editable) {
    return;
  }

  let instance;
  const context = pluginParams.getContext();

  if (trigger instanceof HTMLElement) {
    trigger.id ||= `${TABLE_MENU_IDENTIFIER}-trigger-${++triggerSequence}`;
    trigger.setAttribute("aria-expanded", "false");
  }

  instance = await context.menu.show(trigger, {
    identifier: TABLE_MENU_IDENTIFIER,
    component: NodeMenu,
    placement: options.placement,
    contentRole: "none",
    // The mobile composer sits above the composer dropdown layer, and a sheet
    // is a better touch target than a dropdown anchored to a thin grip.
    modalForMobile: true,
    // Opening from the keyboard is only useful if the items can be reached the
    // same way, and Escape has to land the caret back in the table.
    autofocus: true,
    trapTab: true,
    onClose: () => {
      trigger.setAttribute?.("aria-expanded", "false");
      view.focus();
    },
    data: {
      className: TABLE_MENU_IDENTIFIER,
      items,
      run: (item) => {
        instance?.close();
        item.action();
        if (item.announcement) {
          context.a11y.announce(item.announcement);
        }
      },
    },
  });

  if (instance?.expanded) {
    trigger.setAttribute?.("aria-expanded", "true");
  }

  return instance;
}

export function runCommand(view, command) {
  if (!view.editable) {
    return false;
  }

  const handled = command(view.state, view.dispatch);
  if (handled) {
    view.focus();
  }
  return handled;
}

const ITEMS = {
  insertRowAbove: (view, target) => ({
    icon: "arrow-up",
    label: i18n("composer.table.insert_row_above"),
    className: "composer-table-menu__insert-above",
    announcement: i18n("composer.table.row_inserted"),
    action: () => runCommand(view, addRow(-1, target)),
  }),
  insertRowBelow: (view, target) => ({
    icon: "arrow-down",
    label: i18n("composer.table.insert_row_below"),
    className: "composer-table-menu__insert-below",
    announcement: i18n("composer.table.row_inserted"),
    action: () => runCommand(view, addRow(1, target)),
  }),
  insertColumnLeft: (view, target) => ({
    icon: "arrow-left",
    label: i18n("composer.table.insert_column_left"),
    className: "composer-table-menu__insert-left",
    announcement: i18n("composer.table.column_inserted"),
    action: () => runCommand(view, addColumn(isRtl(view) ? 1 : -1, target)),
  }),
  insertColumnRight: (view, target) => ({
    icon: "arrow-right",
    label: i18n("composer.table.insert_column_right"),
    className: "composer-table-menu__insert-right",
    announcement: i18n("composer.table.column_inserted"),
    action: () => runCommand(view, addColumn(isRtl(view) ? -1 : 1, target)),
  }),
  duplicateRow: (view, target) => ({
    icon: "copy",
    label: i18n("composer.table.duplicate_row"),
    className: "composer-table-menu__duplicate-row",
    announcement: i18n("composer.table.row_duplicated"),
    action: () => runCommand(view, duplicateRow(target)),
  }),
  duplicateColumn: (view, target) => ({
    icon: "copy",
    label: i18n("composer.table.duplicate_column"),
    className: "composer-table-menu__duplicate-column",
    announcement: i18n("composer.table.column_duplicated"),
    action: () => runCommand(view, duplicateColumn(target)),
  }),
  moveRowUp: (view, row, target) => ({
    icon: "arrow-up",
    label: i18n("composer.table.move_row_up"),
    className: "composer-table-menu__move-row-up",
    announcement: i18n("composer.table.row_moved_up"),
    action: () => runCommand(view, moveRow(row, row - 1, target)),
  }),
  moveRowDown: (view, row, target) => ({
    icon: "arrow-down",
    label: i18n("composer.table.move_row_down"),
    className: "composer-table-menu__move-row-down",
    announcement: i18n("composer.table.row_moved_down"),
    action: () => runCommand(view, moveRow(row, row + 2, target)),
  }),
  moveColumnLeft: (view, col, target) => ({
    icon: "arrow-left",
    label: i18n("composer.table.move_column_left"),
    className: "composer-table-menu__move-column-left",
    announcement: i18n("composer.table.column_moved_left"),
    action: () =>
      runCommand(
        view,
        moveColumn(col, isRtl(view) ? col + 2 : col - 1, target)
      ),
  }),
  moveColumnRight: (view, col, target) => ({
    icon: "arrow-right",
    label: i18n("composer.table.move_column_right"),
    className: "composer-table-menu__move-column-right",
    announcement: i18n("composer.table.column_moved_right"),
    action: () =>
      runCommand(
        view,
        moveColumn(col, isRtl(view) ? col - 1 : col + 2, target)
      ),
  }),
  clearContents: (view, target) => ({
    icon: "circle-xmark",
    label: i18n("composer.table.clear_contents"),
    className: "composer-table-menu__clear-contents",
    announcement: i18n("composer.table.contents_cleared"),
    action: () => runCommand(view, clearCellContents(target)),
  }),
  deleteRow: (view, target) => ({
    icon: "trash-can",
    label: i18n("composer.table.delete_row"),
    className: "composer-table-menu__delete-row",
    announcement: i18n("composer.table.row_deleted"),
    dangerous: true,
    action: () => runCommand(view, deleteRow(target)),
  }),
  deleteColumn: (view, target) => ({
    icon: "trash-can",
    label: i18n("composer.table.delete_column"),
    className: "composer-table-menu__delete-column",
    announcement: i18n("composer.table.column_deleted"),
    dangerous: true,
    action: () => runCommand(view, deleteColumn(target)),
  }),
  deleteTable: (view, table) => ({
    icon: "trash-can",
    label: i18n("composer.table.delete_table"),
    className: "composer-table-menu__delete-table",
    announcement: i18n("composer.table.table_deleted"),
    dangerous: true,
    action: () => runCommand(view, deleteTable(table)),
  }),
};

function alignmentItems(view, alignment, target) {
  return ALIGNMENTS.map((value) => ({
    icon: ALIGNMENT_ICONS[value],
    label: i18n(`composer.table.align_${value}`),
    className: `composer-table-menu__align-${value}`,
    active: alignment === value,
    announcement: i18n("composer.table.alignment_changed", {
      alignment: i18n(`composer.table.alignment_${value}`),
    }),
    action: () =>
      runCommand(
        view,
        setColumnAlignment(alignment === value ? null : value, target)
      ),
  }));
}

// A markdown table's first row is its header, so nothing goes above it.
function insertRowAboveItems(view, table, row, target) {
  return table.grid.rows[row].header
    ? []
    : [ITEMS.insertRowAbove(view, target)];
}

function rowMoveItems(view, table, row, target) {
  return [
    ...(row > 0 ? [ITEMS.moveRowUp(view, row, target)] : []),
    ...(row < table.grid.height - 1
      ? [ITEMS.moveRowDown(view, row, target)]
      : []),
  ];
}

function columnMoveItems(view, table, col, target) {
  const last = table.grid.width - 1;
  const rtl = isRtl(view);

  return [
    ...((rtl ? col < last : col > 0)
      ? [ITEMS.moveColumnLeft(view, col, target)]
      : []),
    ...((rtl ? col > 0 : col < last)
      ? [ITEMS.moveColumnRight(view, col, target)]
      : []),
  ];
}

function rowMenuItems(view, { table, row }) {
  const target = rowTarget(table, row);

  return [
    ...insertRowAboveItems(view, table, row, target),
    ITEMS.insertRowBelow(view, target),
    ITEMS.duplicateRow(view, target),
    ...rowMoveItems(view, table, row, target),
    ITEMS.clearContents(view, target),
    { divider: true },
    ITEMS.deleteRow(view, target),
  ];
}

function columnMenuItems(view, { table, col }) {
  const target = columnTarget(table, col);

  return [
    ITEMS.insertColumnLeft(view, target),
    ITEMS.insertColumnRight(view, target),
    ITEMS.duplicateColumn(view, target),
    ...columnMoveItems(view, table, col, target),
    { divider: true },
    ...alignmentItems(view, columnAlignment(table, col), target),
    { divider: true },
    ITEMS.clearContents(view, target),
    ITEMS.deleteColumn(view, target),
  ];
}

// Everything that applies to the cell the caret is in. This is the only menu
// reachable without a pointer, so it has to cover both axes.
export function cellMenuItems(view, { table, row, col }) {
  const cell = cellTarget(table, row, col);
  const column = columnTarget(table, col);
  const rowBand = rowTarget(table, row);

  return [
    ...insertRowAboveItems(view, table, row, rowBand),
    ITEMS.insertRowBelow(view, rowBand),
    ITEMS.insertColumnLeft(view, column),
    ITEMS.insertColumnRight(view, column),
    { divider: true },
    ITEMS.duplicateRow(view, rowBand),
    ITEMS.duplicateColumn(view, column),
    ...rowMoveItems(view, table, row, rowBand),
    ...columnMoveItems(view, table, col, column),
    { divider: true },
    ...alignmentItems(view, columnAlignment(table, col), column),
    { divider: true },
    ITEMS.clearContents(view, cell),
    ITEMS.deleteRow(view, rowBand),
    ITEMS.deleteColumn(view, column),
    ITEMS.deleteTable(view, table),
  ];
}

function isRtl(view) {
  return getComputedStyle(view.dom).direction === "rtl";
}

/**
 * What a context menu opened right now would act on.
 *
 * @returns {{ table: object, row: number, col: number } | null}
 */
export function menuTargetFor(state) {
  const table = currentCell(state);
  if (!table) {
    return null;
  }

  return { table, row: table.rect.top, col: table.rect.left };
}

// Shift+F10 and the ContextMenu key are the platform gesture for "open the menu
// for what is focused", but macOS has neither a ContextMenu key nor F-keys that
// reach the page by default, so Alt+Enter carries the same meaning there.
function opensTableMenu(event) {
  return (
    event.key === "ContextMenu" ||
    (event.key === "F10" && event.shiftKey) ||
    (event.key === "Enter" && event.altKey && !event.ctrlKey && !event.metaKey)
  );
}

export function handleContextMenuKey(view, event, pluginParams) {
  if (!view.editable || !opensTableMenu(event)) {
    return false;
  }

  const target = menuTargetFor(view.state);
  if (!target) {
    return false;
  }

  event.preventDefault();

  const { table, row, col } = target;
  const anchor =
    view.nodeDOM(table.start + table.grid.rows[row].cells[col].offset) ??
    view.dom;

  showMenu(pluginParams, view, anchor, cellMenuItems(view, target), {
    placement: "bottom-start",
  });

  return true;
}
