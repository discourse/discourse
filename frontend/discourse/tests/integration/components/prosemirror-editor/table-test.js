import {
  click,
  find,
  findAll,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { undo } from "prosemirror-history";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import {
  addColumn,
  addRow,
  deleteColumn,
  deleteRow,
  deleteTable,
  duplicateColumn,
  duplicateRow,
  goToNextCell,
  moveColumn,
  moveRow,
  setColumnAlignment,
} from "discourse/static/prosemirror/lib/table/commands";
import { tableGrid } from "discourse/static/prosemirror/lib/table/grid";
import {
  menuItemsFor,
  menuTargetFor,
} from "discourse/static/prosemirror/lib/table/menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

const TABLE = `| h1 | h2 | h3 |\n| --- | --- | --- |\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |`;

function locateTable(view) {
  let node = null;
  let pos = null;
  view.state.doc.descendants((child, at) => {
    if (child.type.name === "table") {
      node = child;
      pos = at;
      return false;
    }
  });
  return { node, pos, start: pos + 1, grid: tableGrid(node) };
}

function cellPos(view, row, col) {
  const { start, grid } = locateTable(view);
  return start + grid.rows[row].cells[col].offset;
}

async function selectCell(view, row, col) {
  const pos = cellPos(view, row, col);
  view.dispatch(
    view.state.tr.setSelection(TextSelection.create(view.state.doc, pos + 1))
  );
  await settled();
}

async function apply(view, command) {
  command(view.state, view.dispatch, view);
  await settled();
}

async function hoverCell(cell) {
  const rect = cell.getBoundingClientRect();
  cell.dispatchEvent(
    new MouseEvent("mousemove", {
      bubbles: true,
      clientX: rect.left + 2,
      clientY: rect.top + 2,
    })
  );
  await settled();
}

async function pressKey(view, key, modifiers = {}) {
  view.dom.dispatchEvent(
    new KeyboardEvent("keydown", {
      key,
      bubbles: true,
      cancelable: true,
      ...modifiers,
    })
  );
  await settled();
}

async function pressGrip(
  grip,
  {
    activate = false,
    click: withClick = false,
    moveBy = 0,
    pointerType = "mouse",
  } = {}
) {
  const rect = grip.getBoundingClientRect();
  const at = {
    bubbles: true,
    cancelable: true,
    button: 0,
    pointerId: 2,
    pointerType,
    isPrimary: true,
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height / 2,
  };

  grip.dispatchEvent(new PointerEvent("pointerdown", at));
  const end = { ...at, clientY: at.clientY + moveBy };
  if (moveBy) {
    document.dispatchEvent(new PointerEvent("pointermove", end));
  }
  document.dispatchEvent(
    new PointerEvent(activate || withClick ? "pointerup" : "pointercancel", end)
  );
  if (withClick) {
    grip.dispatchEvent(new MouseEvent("click", end));
  }
  await settled();
}

// Drags a grip far enough to pass the threshold and drops it over `target`.
async function dragGrip(grip, target, beforeDrop) {
  const from = grip.getBoundingClientRect();
  const to = target.getBoundingClientRect();
  const at = (x, y) => ({
    bubbles: true,
    cancelable: true,
    button: 0,
    pointerId: 1,
    isPrimary: true,
    clientX: x,
    clientY: y,
  });

  grip.dispatchEvent(
    new PointerEvent("pointerdown", at(from.left + 1, from.top + 1))
  );
  document.dispatchEvent(
    new PointerEvent(
      "pointermove",
      at(to.left + to.width / 2 + 1, to.top + to.height / 2 + 1)
    )
  );
  await beforeDrop?.();
  document.dispatchEvent(
    new PointerEvent(
      "pointerup",
      at(to.left + to.width / 2 + 1, to.top + to.height / 2 + 1)
    )
  );
  // The browser sends this after a short drag; a drag must not also open a menu.
  grip.dispatchEvent(new MouseEvent("click", at(to.left, to.top)));
  await settled();
}

async function dragAppend(button, distance) {
  const rect = button.getBoundingClientRect();
  const column = button.classList.contains("--column");
  const start = {
    x: rect.left + rect.width / 2,
    y: rect.top + rect.height / 2,
  };
  const at = (x, y) => ({
    bubbles: true,
    cancelable: true,
    button: 0,
    pointerId: 3,
    isPrimary: true,
    clientX: x,
    clientY: y,
  });
  const end = column
    ? { x: start.x + distance, y: start.y }
    : { x: start.x, y: start.y + distance };

  button.dispatchEvent(new PointerEvent("pointerdown", at(start.x, start.y)));
  document.dispatchEvent(new PointerEvent("pointermove", at(end.x, end.y)));
  document.dispatchEvent(new PointerEvent("pointerup", at(end.x, end.y)));
  button.dispatchEvent(new MouseEvent("click", at(end.x, end.y)));
  await settled();
}

// The editor's table carries its own chrome, which is not part of the document.
function tableMarkup() {
  const table = document
    .querySelector(".ProseMirror .composer-table table")
    .cloneNode(true);
  table.querySelectorAll(".composer-table__grip").forEach((el) => el.remove());
  table
    .querySelectorAll(
      ".is-current-row, .is-current-column, .is-structural-target, .--axis-row, .--axis-column"
    )
    .forEach((cell) => cell.removeAttribute("class"));
  return table.outerHTML;
}

module(
  "Integration | Component | prosemirror-editor - table extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic table": [
        "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |",
        `<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table>`,
        `| Header 1 | Header 2 |\n|----|----|\n| Cell 1 | Cell 2 |\n\n`,
      ],
      "table with alignment": [
        `| Left | Center | Right |\n| :--- | :---: | ---: |\n| A | B | C |`,
        `<table><thead><tr><th style="text-align: left;">Left</th><th style="text-align: center;">Center</th><th style="text-align: right;">Right</th></tr></thead><tbody><tr><td style="text-align: left;">A</td><td style="text-align: center;">B</td><td style="text-align: right;">C</td></tr></tbody></table>`,
        `| Left | Center | Right |\n|:---|:---:|---:|\n| A | B | C |\n\n`,
      ],
      "table with br in cells": [
        `| Line1<br>Line2 | Cell 2 |\n| --- | --- |\n| Cell 3 | Cell 4 |`,
        `<table><thead><tr><th>Line1<br>Line2</th><th>Cell 2</th></tr></thead><tbody><tr><td>Cell 3</td><td>Cell 4</td></tr></tbody></table>`,
        `| Line1<br>Line2 | Cell 2 |\n|----|----|\n| Cell 3 | Cell 4 |\n\n`,
      ],
      "table with pipes inside a link": [
        `| Link | Note |\n| --- | --- |\n| [x|y](https://example.com "title|value") | ok |`,
        `<table><thead><tr><th>Link</th><th>Note</th></tr></thead><tbody><tr><td><a href="https://example.com" title="title|value">x|y</a></td><td>ok</td></tr></tbody></table>`,
        `| Link | Note |\n|----|----|\n| [x\\|y](https://example.com "title\\|value") | ok |\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(
          assert,
          markdown,
          (a) =>
            a.strictEqual(tableMarkup(), html, "table markup should match"),
          expectedMarkdown
        );
      });
    });

    test("table within quotes", async function (assert) {
      await testMarkdown(
        assert,
        `> \n> | Header 1 | Header 2 |\n> | --- | --- |\n> | Cell 1 | Cell 2 |\n`,
        (a) => {
          a.dom(".ProseMirror blockquote .composer-table table").exists();
          a.strictEqual(
            tableMarkup(),
            `<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table>`
          );
        },
        `> \n> | Header 1 | Header 2 |\n> |----|----|\n> | Cell 1 | Cell 2 |\n\n`
      );
    });

    test("renders a grip for every row and column", async function (assert) {
      await setupRichEditor(assert, TABLE);

      assert.dom(".composer-table__grip.--column").exists({ count: 3 });
      assert.dom(".composer-table__grip.--row").exists({ count: 3 });
      assert.dom(".composer-table__append.--column").exists();
      assert.dom(".composer-table__append.--row").exists();
    });

    test("adds and deletes columns", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 1);
      await apply(view, addColumn(1));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 |  | h3 |\n|----|----|----|----|\n| a1 | a2 |  | a3 |\n| b1 | b2 |  | b3 |\n\n`,
        "inserts an empty column after the selected one"
      );

      await selectCell(view, 1, 2);
      await apply(view, deleteColumn());

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "removes the column again"
      );
    });

    test("adds and deletes rows", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 0);
      await apply(view, addRow(-1));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n|  |  |  |\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "inserts an empty row above the selected one"
      );

      await selectCell(view, 1, 0);
      await apply(view, deleteRow());

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "removes the row again"
      );
    });

    test("deleting the header row promotes the next one", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 0, 0);
      await apply(view, deleteRow());

      assert.strictEqual(
        editor.value,
        `| a1 | a2 | a3 |\n|----|----|----|\n| b1 | b2 | b3 |\n\n`,
        "a markdown table always keeps a header row"
      );
    });

    test("alignment survives a header promotion", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `| h1 | h2 |\n| --- | :---: |\n| a1 | a2 |\n| b1 | b2 |`
      );
      const { view } = editor;

      await selectCell(view, 0, 0);
      await apply(view, deleteRow());

      assert.strictEqual(
        editor.value,
        `| a1 | a2 |\n|----|:---:|\n| b1 | b2 |\n\n`,
        "the promoted row carries the column's alignment"
      );
    });

    test("alignment travels with a moved column", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `| h1 | h2 |\n| --- | :---: |\n| a1 | a2 |`
      );
      const { view } = editor;

      await selectCell(view, 1, 0);
      await apply(view, moveColumn(1, 0));

      assert.strictEqual(
        editor.value,
        `| h2 | h1 |\n|:---:|----|\n| a2 | a1 |\n\n`
      );
    });

    test("sets alignment for the whole column", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 2, 1);
      await apply(view, setColumnAlignment("center"));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|:---:|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`
      );

      assert
        .dom(
          ".ProseMirror .composer-table tbody tr:first-child td:nth-child(2)"
        )
        .hasStyle({ textAlign: "center" }, "body cells follow the column");
    });

    test("reorders rows and columns", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 0);
      await apply(view, moveRow(1, 3));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| b1 | b2 | b3 |\n| a1 | a2 | a3 |\n\n`,
        "moves a row down"
      );

      await selectCell(view, 1, 0);
      await apply(view, moveColumn(0, 3));

      assert.strictEqual(
        editor.value,
        `| h2 | h3 | h1 |\n|----|----|----|\n| b2 | b3 | b1 |\n| a2 | a3 | a1 |\n\n`,
        "moves a column to the end"
      );
    });

    test("Tab walks the cells and appends a row at the end", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 0, 0);
      await apply(view, goToNextCell(1));

      assert.strictEqual(
        view.state.selection.$from.parent.textContent,
        "h2",
        "moves to the next cell"
      );

      await selectCell(view, 2, 2);
      await apply(view, goToNextCell(1));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n|  |  |  |\n\n`,
        "appends a row past the last cell"
      );
    });

    test("a caret in a cell targets both of its axes", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 1);
      const target = menuTargetFor(view.state);

      assert.strictEqual(target.kind, "cell");
      assert.deepEqual(
        menuItemsFor(view, target)
          .filter((item) => !item.divider)
          .map((item) => item.className),
        [
          "composer-table-menu__insert-above",
          "composer-table-menu__insert-below",
          "composer-table-menu__insert-left",
          "composer-table-menu__insert-right",
          "composer-table-menu__duplicate-row",
          "composer-table-menu__duplicate-column",
          "composer-table-menu__move-row-up",
          "composer-table-menu__move-row-down",
          "composer-table-menu__move-column-left",
          "composer-table-menu__move-column-right",
          "composer-table-menu__align-left",
          "composer-table-menu__align-center",
          "composer-table-menu__align-right",
          "composer-table-menu__clear-contents",
          "composer-table-menu__delete-row",
          "composer-table-menu__delete-column",
          "composer-table-menu__delete-table",
        ],
        "every table command is reachable from one cell"
      );
    });

    test("the keyboard opens the rendered cell menu and clears its cell", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE, {
        withMenus: true,
      });
      const { view } = editor;

      await selectCell(view, 1, 1);
      await pressKey(view, "Enter", { altKey: true });
      await waitFor('.fk-d-menu[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-row")
        .doesNotHaveAttribute(
          "aria-keyshortcuts",
          "a cell menu does not advertise a row shortcut"
        );
      assert
        .dom(".composer-table-menu__align-left")
        .hasAttribute("aria-pressed", "false");
      assert
        .dom(".composer-table-menu__align-center")
        .hasAttribute("aria-pressed", "false");

      await click(".composer-table-menu__clear-contents");

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 |  | a3 |\n| b1 | b2 | b3 |\n\n`,
        "clear contents works from a caret"
      );
    });

    test("the header row is never offered an insert above", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 0, 0);
      const items = menuItemsFor(view, menuTargetFor(view.state));

      assert.false(
        items.some(
          (item) => item.className === "composer-table-menu__insert-above"
        )
      );
    });

    test("a caret outside a table has no target", async function (assert) {
      const [editor] = await setupRichEditor(assert, `text\n\n${TABLE}`);
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 2))
      );
      await settled();

      assert.strictEqual(menuTargetFor(view.state), null);
    });

    test("a grip highlights its row without replacing the caret", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;
      await selectCell(view, 2, 1);
      const caret = view.state.selection.from;

      await pressGrip(findAll(".composer-table__grip.--row")[1]);
      assert
        .dom(".ProseMirror .composer-table .is-structural-target")
        .exists({ count: 3 }, "one row");
      assert.strictEqual(
        view.state.selection.from,
        caret,
        "the document selection remains a caret"
      );
    });

    test("clicking a row grip opens its rendered action menu", async function (assert) {
      await setupRichEditor(assert, TABLE, { withMenus: true });
      const grip = document.querySelectorAll(".composer-table__grip.--row")[1];

      await click(grip);
      await waitFor('.fk-d-menu[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-row")
        .exists("the selected row's actions are rendered");
      assert
        .dom(".composer-table-menu__clear-contents")
        .exists("the menu can clear the targeted row");
      assert
        .dom(grip)
        .hasAttribute("aria-expanded", "true", "the grip exposes menu state");

      const menuBounds = find(
        '.fk-d-menu[data-identifier="composer-table-menu"]'
      ).getBoundingClientRect();
      assert.notDeepEqual(
        [Math.round(menuBounds.left), Math.round(menuBounds.top)],
        [0, 0],
        "the menu is positioned from its connected grip"
      );
    });

    test("clicking a column grip opens its rendered action menu", async function (assert) {
      await setupRichEditor(assert, TABLE, { withMenus: true });
      const grip = document.querySelectorAll(
        ".composer-table__grip.--column"
      )[1];

      await click(grip);
      await waitFor('.fk-d-menu[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-column")
        .exists("the selected column's actions are rendered");
      assert
        .dom(".composer-table-menu__clear-contents")
        .exists("the menu can clear the targeted column");
      assert
        .dom(grip)
        .hasAttribute("aria-expanded", "true", "the grip exposes menu state");
    });

    test("tapping a grip opens the table actions on mobile", async function (assert) {
      forceMobile();
      await setupRichEditor(assert, TABLE, { withMenus: true });
      const grip = findAll(".composer-table__grip.--row")[1];

      await pressGrip(grip, {
        activate: true,
        moveBy: 6,
        pointerType: "touch",
      });
      await waitFor('.fk-d-menu-modal[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-row")
        .exists("the row actions render in a touch-friendly sheet");
    });

    test("an active mobile grip does not expose vertical table scrolling", async function (assert) {
      forceMobile();
      await setupRichEditor(assert, TABLE);
      const scroller = find(".composer-table");

      await pressGrip(findAll(".composer-table__grip.--column")[1]);

      assert.strictEqual(
        getComputedStyle(scroller).overflowY,
        "hidden",
        "horizontal overflow cannot induce a second scrollbar"
      );
    });

    test("touch dragging the table body scrolls it horizontally", async function (assert) {
      await setupRichEditor(assert, TABLE);
      const scroller = find(".composer-table");
      const inner = find(".composer-table__inner");
      const cell = find(".composer-table td");

      Object.assign(scroller.style, { width: "12rem" });
      Object.assign(inner.style, { width: "36rem" });
      scroller.scrollLeft = 0;

      const at = (x, y) => ({
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 11,
        pointerType: "touch",
        isPrimary: true,
        clientX: x,
        clientY: y,
      });

      cell.dispatchEvent(new PointerEvent("pointerdown", at(160, 50)));
      document.dispatchEvent(new PointerEvent("pointermove", at(60, 52)));

      assert.strictEqual(
        getComputedStyle(scroller).overflowX,
        "auto",
        "the table owns its horizontal overflow"
      );
      assert.true(
        scroller.scrollLeft > 0,
        "a horizontal touch gesture moves the table"
      );

      document.dispatchEvent(new PointerEvent("pointerup", at(60, 52)));
      assert
        .dom(scroller)
        .doesNotHaveClass("is-panning", "the transient gesture state clears");
    });

    test("table chrome reserves only the touch gestures it uses", async function (assert) {
      await setupRichEditor(assert, TABLE);

      assert.strictEqual(
        getComputedStyle(find(".composer-table table")).touchAction,
        "pan-y pinch-zoom",
        "the table body keeps vertical page scrolling and pinch zoom"
      );

      for (const control of findAll(".composer-table__grip")) {
        assert.strictEqual(
          getComputedStyle(control).touchAction,
          "none",
          "a grip keeps small tap movements from being canceled"
        );
      }

      assert.strictEqual(
        getComputedStyle(find(".composer-table__append.--row")).touchAction,
        "pan-x pinch-zoom",
        "the row append bar leaves native horizontal panning available"
      );
      assert.strictEqual(
        getComputedStyle(find(".composer-table__append.--column")).touchAction,
        "pan-y pinch-zoom",
        "the column append bar leaves vertical page scrolling available"
      );
    });

    test("an assistive click opens a grip without pointer events", async function (assert) {
      await setupRichEditor(assert, TABLE, { withMenus: true });
      const grip = findAll(".composer-table__grip.--column")[1];

      grip.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      await waitFor('.fk-d-menu[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-column")
        .exists("synthesized activation remains supported");
    });

    test("a canceled grip drag does not swallow the next click", async function (assert) {
      await setupRichEditor(assert, TABLE, { withMenus: true });
      const grip = document.querySelectorAll(".composer-table__grip.--row")[1];
      const bounds = grip.getBoundingClientRect();
      const at = (y) => ({
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 9,
        isPrimary: true,
        clientX: bounds.left + 1,
        clientY: y,
      });

      grip.dispatchEvent(new PointerEvent("pointerdown", at(bounds.top + 1)));
      document.dispatchEvent(
        new PointerEvent("pointermove", at(bounds.top + 10))
      );
      document.dispatchEvent(
        new PointerEvent("pointercancel", at(bounds.top + 10))
      );
      grip.dispatchEvent(new MouseEvent("click", at(bounds.top + 10)));
      await settled();

      assert
        .dom('.fk-d-menu[data-identifier="composer-table-menu"]')
        .doesNotExist("the drag's synthesized click is ignored");

      const currentGrip = document.querySelectorAll(
        ".composer-table__grip.--row"
      )[1];
      await pressGrip(currentGrip, { click: true });
      await waitFor('.fk-d-menu[data-identifier="composer-table-menu"]');

      assert
        .dom(".composer-table-menu__duplicate-row")
        .exists("the next genuine click opens the menu");
    });

    test("duplicating a row and a column copies their contents", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 0);
      await apply(view, duplicateRow());

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`
      );

      await selectCell(view, 1, 1);
      await apply(view, duplicateColumn());

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h2 | h3 |\n|----|----|----|----|\n| a1 | a2 | a2 | a3 |\n| a1 | a2 | a2 | a3 |\n| b1 | b2 | b2 | b3 |\n\n`
      );
    });

    test("deleting the table removes it from the document", async function (assert) {
      const [editor] = await setupRichEditor(assert, `before\n\n${TABLE}`);
      const { view } = editor;

      await selectCell(view, 1, 1);
      await apply(view, deleteTable());

      assert.strictEqual(editor.value, "before");
      assert.dom(".ProseMirror .composer-table").doesNotExist();
    });

    test("Tab moves between cells through the keymap", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 0, 0);
      await pressKey(view, "Tab");

      assert.strictEqual(view.state.selection.$from.parent.textContent, "h2");

      await pressKey(view, "Tab", { shiftKey: true });

      assert.strictEqual(view.state.selection.$from.parent.textContent, "h1");
    });

    test("a cell that ends up the wrong type is corrected", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      const pos = cellPos(view, 1, 0);
      const cell = view.state.doc.nodeAt(pos);
      view.dispatch(
        view.state.tr.setNodeMarkup(
          pos,
          view.state.schema.nodes.table_header_cell,
          cell.attrs
        )
      );
      await settled();

      assert.strictEqual(
        view.state.doc.nodeAt(cellPos(view, 1, 0)).type.name,
        "table_cell",
        "a header cell in the body is put back"
      );
    });

    // Merged cells and header columns are expressible in a post through the
    // sanitized HTML subset, which this editor keeps verbatim rather than
    // flattening into a pipe table that cannot represent them.
    Object.entries({
      colspan: `<table>\n<thead>\n<tr><th>A</th><th colspan="2">B</th></tr>\n</thead>\n<tbody>\n<tr><td>1</td><td>2</td><td>3</td></tr>\n</tbody>\n</table>`,
      rowspan: `<table>\n<tbody>\n<tr><td rowspan="2">A</td><td>1</td></tr>\n<tr><td>2</td></tr>\n</tbody>\n</table>`,
      "header column": `<table>\n<tbody>\n<tr><th>Row A</th><td>1</td></tr>\n<tr><th>Row B</th><td>2</td></tr>\n</tbody>\n</table>`,
    }).forEach(([name, markdown]) => {
      test(`an HTML table with ${name} survives untouched`, async function (assert) {
        const [editor] = await setupRichEditor(assert, markdown);

        assert.strictEqual(editor.value, `${markdown}\n\n`);
        assert.dom(".ProseMirror .composer-table").doesNotExist();
        assert.dom(".ProseMirror .html-block").exists();
      });
    });

    test("hovering a cell reveals only its own row and column handle", async function (assert) {
      await setupRichEditor(assert, TABLE);

      assert
        .dom(".composer-table__grip.is-visible")
        .doesNotExist("no pointer-specific handles are shown yet");

      const cell = [
        ...document.querySelectorAll(".ProseMirror .composer-table td"),
      ].find((td) => td.textContent === "b2");
      await hoverCell(cell);

      const shown = [
        ...document.querySelectorAll(".composer-table__grip.is-visible"),
      ];
      assert.strictEqual(shown.length, 2, "one per axis, not the whole set");

      const cellOf = (grip) => grip.closest("th, td");
      assert.strictEqual(
        cellOf(shown.find((g) => g.classList.contains("--column"))).textContent,
        "h2",
        "the handle for the hovered column"
      );
      assert.strictEqual(
        cellOf(shown.find((g) => g.classList.contains("--row"))).textContent,
        "b1",
        "and for the hovered row"
      );
    });

    test("a caret keeps pointer-specific handles quiet", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);

      await selectCell(editor.view, 2, 1);

      assert
        .dom(".composer-table__grip.is-visible")
        .doesNotExist("typing does not summon structural chrome");
      assert.dom(".composer-table.is-active").exists("the table stays active");
      assert
        .dom(".composer-table .is-current-row")
        .exists({ count: 1 }, "touch has one caret-aware row target");
      assert
        .dom(".composer-table .is-current-column")
        .exists({ count: 1 }, "and one caret-aware column target");
    });

    test("only the caret's handles are exposed to assistive technology", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);

      await selectCell(editor.view, 2, 1);

      const grips = [...document.querySelectorAll(".composer-table__grip")];
      const exposed = grips.filter(
        (grip) => grip.getAttribute("aria-hidden") === "false"
      );

      assert.strictEqual(grips.length, 6, "every row and column has one");
      assert.strictEqual(
        exposed.length,
        2,
        "only one control per axis is exposed"
      );
      assert.deepEqual(
        exposed.map((grip) => grip.getAttribute("aria-label")).sort(),
        ["Column 2 actions", "Row 3 actions"],
        "the controls name the structure they act on"
      );
      grips
        .filter((grip) => !exposed.includes(grip))
        .forEach((grip) =>
          assert.dom(grip).hasAttribute("aria-hidden", "true")
        );
    });

    test("a disabled editor hides table chrome and rejects its events", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE, {
        disabled: true,
        withMenus: true,
      });
      const before = editor.value;
      const grip = find(".composer-table__grip.--row");
      const append = find(".composer-table__append.--row");

      assert.dom(grip).hasAttribute("hidden");
      assert.dom(append).hasAttribute("hidden");

      grip.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      append.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      menuItemsFor(editor.view, menuTargetFor(editor.view.state))
        .find((item) => item.className === "composer-table-menu__insert-below")
        .action();
      await pressKey(editor.view, "Enter", { altKey: true });
      await settled();

      assert.strictEqual(editor.value, before, "the document is unchanged");
      assert
        .dom('.fk-d-menu[data-identifier="composer-table-menu"]')
        .doesNotExist("no table action menu opens");
    });

    test("a structural target marks the sides that face out of it", async function (assert) {
      await setupRichEditor(assert, TABLE);

      await pressGrip(findAll(".composer-table__grip.--row")[1]);

      const edges = [
        ...document.querySelectorAll(
          ".ProseMirror .composer-table .is-structural-target"
        ),
      ].map((cell) =>
        [...cell.classList]
          .filter((name) => name.startsWith("--edge"))
          .sort()
          .join(" ")
      );

      assert.deepEqual(
        edges,
        [
          "--edge-bottom --edge-left --edge-top",
          "--edge-bottom --edge-top",
          "--edge-bottom --edge-right --edge-top",
        ],
        "the highlighted row has one continuous boundary"
      );
    });

    // A drag that ends away from the small append bar gets no click on it, so
    // the flag that swallows the drag's click must not outlive the gesture.
    test("clicking an append bar after dragging it still adds one", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const columns = () =>
        document.querySelectorAll(".ProseMirror .composer-table th").length;
      const button = find(".composer-table__append.--column");
      const rect = button.getBoundingClientRect();
      const at = (x) => ({
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 4,
        isPrimary: true,
        clientX: x,
        clientY: rect.top + rect.height / 2,
      });
      const origin = rect.left + rect.width / 2;

      button.dispatchEvent(new PointerEvent("pointerdown", at(origin)));
      document.dispatchEvent(new PointerEvent("pointermove", at(origin + 600)));
      document.dispatchEvent(new PointerEvent("pointerup", at(origin + 600)));
      await settled();

      const afterDrag = columns();
      assert.true(afterDrag > 3, "the drag added columns");

      button.dispatchEvent(new PointerEvent("pointerdown", at(origin)));
      document.dispatchEvent(new PointerEvent("pointerup", at(origin)));
      button.dispatchEvent(new MouseEvent("click", at(origin)));
      await settled();

      assert.strictEqual(
        columns(),
        afterDrag + 1,
        "and a plain click afterwards still adds one"
      );
      assert.strictEqual(
        editor.value.split("\n")[0].split("|").length - 2,
        afterDrag + 1,
        "the markdown has the same column count"
      );
    });

    test("dragging an append bar back removes empty rows or columns", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `| h1 | h2 |\n| --- | --- |\n| a1 | a2 |`
      );
      const columns = () => editor.value.split("\n")[0].split("|").length - 2;
      const before = columns();

      await dragAppend(find(".composer-table__append.--column"), 400);
      const added = columns();
      assert.true(added > before, `columns added (${before} -> ${added})`);

      await dragAppend(find(".composer-table__append.--column"), -400);
      assert.strictEqual(
        columns(),
        before,
        "dragging back the same way drops the empty ones again"
      );
    });

    test("dragging back never removes a row or column with content", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const before = editor.value;

      await dragAppend(find(".composer-table__append.--column"), -600);
      assert.strictEqual(
        editor.value,
        before,
        "every column carries content, so there is nothing to take away"
      );

      await dragAppend(find(".composer-table__append.--row"), -600);
      assert.strictEqual(editor.value, before, "and the same for rows");
    });

    test("a row can be dragged into and out of the header", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 2, 0);
      await apply(view, moveRow(2, 0));

      assert.strictEqual(
        editor.value,
        `| b1 | b2 | b3 |\n|----|----|----|\n| h1 | h2 | h3 |\n| a1 | a2 | a3 |\n\n`,
        "the row that lands first becomes the header"
      );

      await selectCell(view, 0, 0);
      await apply(view, moveRow(0, 3));

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "and the old header becomes a body row on the way back"
      );
    });

    test("crossing the header re-types the cells it moves", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 0);
      await apply(view, moveRow(1, 0));

      const types = [];
      view.state.doc.descendants((node) => {
        if (node.type.spec.tableRole === "row") {
          types.push(
            [...node.children].map((cell) => cell.type.name).join(",")
          );
        }
      });

      assert.strictEqual(
        types[0],
        "table_header_cell,table_header_cell,table_header_cell",
        "the promoted row holds header cells"
      );
      assert.strictEqual(
        types[1],
        "table_cell,table_cell,table_cell",
        "and the demoted one holds body cells"
      );
    });

    test("the append bars grow the table", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);

      await click(".composer-table__append.--column");

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |  |\n|----|----|----|----|\n| a1 | a2 | a3 |  |\n| b1 | b2 | b3 |  |\n\n`,
        "appends a column at the right edge"
      );

      await click(".composer-table__append.--row");

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |  |\n|----|----|----|----|\n| a1 | a2 | a3 |  |\n| b1 | b2 | b3 |  |\n|  |  |  |  |\n\n`,
        "appends a row at the bottom edge"
      );
    });

    test("dragging an append bar adds multiple rows or columns", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const table = find(".composer-table table");
      table.getBoundingClientRect = () => ({ width: 300, height: 90 });

      await dragAppend(find(".composer-table__append.--column"), 200);
      await dragAppend(find(".composer-table__append.--row"), 60);

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |  |  |\n|----|----|----|----|----|\n| a1 | a2 | a3 |  |  |\n| b1 | b2 | b3 |  |  |\n|  |  |  |  |  |\n|  |  |  |  |  |\n\n`,
        "the drag distance controls how many are appended"
      );
    });

    test("a narrow table does not over-count a column drag", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const table = find(".composer-table table");
      table.getBoundingClientRect = () => ({ width: 90, height: 90 });

      await dragAppend(find(".composer-table__append.--column"), 100);

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |  |\n|----|----|----|----|\n| a1 | a2 | a3 |  |\n| b1 | b2 | b3 |  |\n\n`,
        "the drag uses a usable column width instead of the collapsed table width"
      );
    });

    test("a long append drag is capped", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const table = find(".composer-table table");
      table.getBoundingClientRect = () => ({ width: 300, height: 90 });

      await dragAppend(find(".composer-table__append.--column"), 10_000);

      assert.strictEqual(
        editor.value.split("\n")[0].split("|").length - 2,
        11,
        "one gesture adds at most eight columns"
      );
    });

    test("an append drag autoscrolls at the table edge", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const scroller = find(".composer-table");
      const button = find(".composer-table__append.--column");
      const inner = find(".composer-table__inner");
      Object.assign(scroller.style, {
        width: "200px",
        overflowX: "auto",
      });
      inner.style.width = "600px";
      scroller.scrollLeft = 0;
      const bounds = scroller.getBoundingClientRect();

      const at = (x) => ({
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 8,
        isPrimary: true,
        clientX: x,
        clientY: 50,
      });
      button.dispatchEvent(
        new PointerEvent("pointerdown", at(bounds.left + bounds.width / 2))
      );
      document.dispatchEvent(
        new PointerEvent("pointermove", at(bounds.right - 2))
      );
      await waitUntil(
        () =>
          find(".composer-table__append.--column .composer-table__append-count")
            .textContent === "+2"
      );

      assert.true(scroller.scrollLeft > 0, "the table scrolls under the drag");

      document.dispatchEvent(
        new PointerEvent("pointerup", at(bounds.right - 2))
      );
      await settled();

      assert.true(
        editor.value.split("\n")[0].split("|").length - 2 >= 5,
        "stationary edge scrolling advances the append count"
      );
    });

    test("a row reorder autoscrolls at the composer edge", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const scroller = find(".composer-table");
      const inner = find(".composer-table__inner");
      const grip = document.querySelectorAll(".composer-table__grip.--row")[1];
      Object.assign(scroller.style, {
        height: "70px",
        overflowY: "auto",
      });
      inner.style.height = "300px";
      const gripBounds = grip.getBoundingClientRect();
      const bounds = scroller.getBoundingClientRect();
      const at = (y) => ({
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 9,
        isPrimary: true,
        clientX: gripBounds.left + gripBounds.width / 2,
        clientY: y,
      });

      grip.dispatchEvent(
        new PointerEvent(
          "pointerdown",
          at(gripBounds.top + gripBounds.height / 2)
        )
      );
      document.dispatchEvent(
        new PointerEvent("pointermove", at(bounds.bottom - 2))
      );
      await new Promise((resolve) => setTimeout(resolve, 50));

      assert.true(
        scroller.scrollTop > 0,
        "the composer scrolls while the pointer stays at its lower edge"
      );

      document.dispatchEvent(
        new PointerEvent("pointerup", at(bounds.bottom - 2))
      );
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| b1 | b2 | b3 |\n| a1 | a2 | a3 |\n\n`,
        "releasing a stationary pointer uses the autoscrolled landing target"
      );
    });

    test("a text selection across cells remains ordinary text selection", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      const from = cellPos(view, 1, 0) + 1;
      const to = cellPos(view, 1, 2) + 2;
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, from, to)
        )
      );
      await settled();

      assert.strictEqual(
        view.state.selection.constructor,
        TextSelection,
        "the editor does not replace the browser's selection model"
      );
      assert
        .dom(".ProseMirror .composer-table .is-structural-target")
        .doesNotExist("no spreadsheet-style selection is introduced");
    });

    test("Delete across cells preserves their boundaries", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            cellPos(view, 1, 0) + 2,
            cellPos(view, 1, 2) + 2
          )
        )
      );
      await pressKey(view, "Delete");

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a |  | 3 |\n| b1 | b2 | b3 |\n\n`,
        "only selected cell content is removed"
      );
      assert.strictEqual(
        locateTable(view).grid.width,
        3,
        "the row keeps all of its cells"
      );
    });

    test("mobile deletion across table sections preserves their structure", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            cellPos(view, 0, 2) + 2,
            cellPos(view, 1, 0) + 2
          )
        )
      );
      view.dom.dispatchEvent(
        new InputEvent("beforeinput", {
          bubbles: true,
          cancelable: true,
          inputType: "deleteContentBackward",
        })
      );
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h |\n|----|----|----|\n| 1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "content is removed without joining the header and body"
      );
      assert.deepEqual(
        locateTable(view).grid.rows.map((row) =>
          row.cells.map((cell) => cell.node.type.name)
        ),
        [
          ["table_header_cell", "table_header_cell", "table_header_cell"],
          ["table_cell", "table_cell", "table_cell"],
          ["table_cell", "table_cell", "table_cell"],
        ],
        "each section keeps the correct cell types"
      );
    });

    test("typing across cells is one safe undoable edit", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            cellPos(view, 0, 2) + 2,
            cellPos(view, 1, 0) + 2
          )
        )
      );
      view.dom.dispatchEvent(
        new KeyboardEvent("keypress", {
          bubbles: true,
          cancelable: true,
          charCode: 88,
          key: "X",
          keyCode: 88,
        })
      );
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | hX |\n|----|----|----|\n| 1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "text lands in the first cell without joining cells"
      );
      assert.true(view.state.selection.empty, "the replacement leaves a caret");

      await apply(view, undo);
      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "one undo restores the range"
      );
    });

    test("pasting text across cells preserves the grid", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            cellPos(view, 1, 0) + 2,
            cellPos(view, 1, 1) + 2
          )
        )
      );
      view.pasteHTML("<p>Z</p>");
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| aZ | 2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "the paste replaces content rather than cell nodes"
      );
    });

    test("cutting across cells preserves the grid and is undoable", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;
      const clipboardData = new DataTransfer();

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            cellPos(view, 1, 0) + 2,
            cellPos(view, 1, 1) + 2
          )
        )
      );
      view.dom.dispatchEvent(
        new ClipboardEvent("cut", {
          bubbles: true,
          cancelable: true,
          clipboardData,
        })
      );
      await settled();

      assert.strictEqual(clipboardData.getData("text/plain"), "1\n\na");
      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a | 2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "the cut removes content without joining cells"
      );

      await apply(view, undo);
      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`,
        "one undo restores the cut range"
      );
    });

    test("a row left short of cells is padded back out", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      const pos = cellPos(view, 1, 2);
      const cell = view.state.doc.nodeAt(pos);
      view.dispatch(view.state.tr.delete(pos, pos + cell.nodeSize));
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 |  |\n| b1 | b2 | b3 |\n\n`,
        "the grid stays rectangular"
      );
    });

    test("pasting a table into a cell fills the grid instead of nesting", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 1);
      view.pasteHTML(
        "<table><tbody><tr><td>x1</td><td>x2</td></tr><tr><td>y1</td><td>y2</td></tr></tbody></table>"
      );
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | x1 | x2 |\n| b1 | y1 | y2 |\n\n`,
        "the pasted cells land at the target cell"
      );
    });

    test("pasting a table larger than the grid grows it", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 2, 2);
      view.pasteHTML(
        "<table><tbody><tr><td>x1</td><td>x2</td></tr><tr><td>y1</td><td>y2</td></tr></tbody></table>"
      );
      await settled();

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |  |\n|----|----|----|----|\n| a1 | a2 | a3 |  |\n| b1 | b2 | x1 | x2 |\n|  |  | y1 | y2 |\n\n`,
        "the table is extended to fit the paste"
      );
    });

    test("pasting a table alongside other content keeps the other content", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 1);
      view.pasteHTML("<hr><table><tbody><tr><td>x1</td></tr></tbody></table>");
      await settled();

      let horizontalRules = 0;
      editor.view.state.doc.descendants((node) => {
        if (node.type.name === "horizontal_rule") {
          horizontalRules++;
        }
      });
      assert.strictEqual(
        horizontalRules,
        1,
        "a non-text block beside the table is not dropped"
      );
    });

    test("structural edits undo in one step", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);
      const { view } = editor;

      await selectCell(view, 1, 1);
      await apply(view, addColumn(1));
      await apply(view, undo);

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| a1 | a2 | a3 |\n| b1 | b2 | b3 |\n\n`
      );
    });

    test("an imported table with no rows is removed safely", async function (assert) {
      const [editor] = await setupRichEditor(assert, "before");
      const { schema, tr } = editor.view.state;
      const emptyTable = schema.nodes.table.create(
        null,
        schema.nodes.table_body.create()
      );

      editor.view.dispatch(
        tr.replaceWith(0, editor.view.state.doc.content.size, emptyTable)
      );
      await settled();

      assert.dom(".composer-table").doesNotExist();
      assert.notStrictEqual(
        editor.view.state.doc.firstChild.type.name,
        "table",
        "the editor does not leave invalid append chrome behind"
      );
    });

    test("dragging a row grip past another row reorders them", async function (assert) {
      const [editor] = await setupRichEditor(assert, TABLE);

      const grips = [
        ...document.querySelectorAll(".composer-table__grip.--row"),
      ];
      const rows = [
        ...document.querySelectorAll(".ProseMirror .composer-table table tr"),
      ];
      await dragGrip(grips[1], rows[2]);

      assert.strictEqual(
        editor.value,
        `| h1 | h2 | h3 |\n|----|----|----|\n| b1 | b2 | b3 |\n| a1 | a2 | a3 |\n\n`,
        "the dragged row lands past the one it was dropped over"
      );
    });

    test("dragging a column grip to the right reorders unequal cells", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `| short | a much longer heading | x |\n| --- | --- | --- |\n| one | a much longer value | three |`
      );

      const grips = [
        ...document.querySelectorAll(".composer-table__grip.--column"),
      ];
      const cells = [
        ...document.querySelectorAll(".ProseMirror .composer-table table th"),
      ];
      await dragGrip(grips[0], cells[2], () => {
        assert.true(
          !!document.querySelector(".composer-table__drag-avatar.--column"),
          "the portaled active grip follows the pointer during the drag"
        );
        assert.true(
          document
            .querySelector(".composer-table__drag-avatar.--column")
            .style.transform.startsWith("translateX("),
          "the avatar carries the same horizontal drag offset"
        );
      });

      assert.strictEqual(
        editor.value,
        `| a much longer heading | x | short |\n|----|----|----|\n| a much longer value | three | one |\n\n`,
        "the dragged column lands past the one it was dropped over"
      );
    });

    test("dragging a column grip to the left reorders unequal cells", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `| short | a much longer heading | x |\n| --- | --- | --- |\n| one | a much longer value | three |`
      );
      const grips = [
        ...document.querySelectorAll(".composer-table__grip.--column"),
      ];
      const cells = [
        ...document.querySelectorAll(".ProseMirror .composer-table table th"),
      ];

      await dragGrip(grips[2], cells[0]);

      assert.strictEqual(
        editor.value,
        `| x | short | a much longer heading |\n|----|----|----|\n| three | one | a much longer value |\n\n`,
        "the reverse direction uses the same insertion geometry"
      );
    });
  }
);
