import { getOwner } from "@ember/owner";
import { find, findAll, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  dragOver,
  simulateDrag,
  startDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import BoardsColumn from "discourse/plugins/boards/discourse/components/boards-column";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

const columnSelector = '[data-column-id="20"]';
const cardsSelector = `${columnSelector} .discourse-boards-column__cards`;
const emptySelector = `${columnSelector} .discourse-boards-column__empty`;

/** Accept the legacy spacer and the primitive's CSS-only indicators. */
const indicatorSelector = [
  `${cardsSelector} .discourse-boards-column__drop-indicator:not(.discourse-boards-column__drop-indicator--source)`,
  `${columnSelector}[data-drop-target].--drag-inside`,
  `${columnSelector} [data-drop-target].--drag-inside`,
  `${columnSelector} [data-drop-target].--drag-above`,
  `${columnSelector} [data-drop-target].--drag-below`,
].join(", ");

function cardSelector(id) {
  return `.discourse-boards-card[data-card-id="${id}"]`;
}

function pointOnCard(id, fraction) {
  const rect = find(cardSelector(id)).getBoundingClientRect();
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height * fraction,
  };
}

/** Preserve native events on the baseline without forging registration attributes. */
async function completeDrag(source, target, targetCoordinates) {
  const dataTransfer = new DataTransfer();
  if (find(source).hasAttribute("data-drag-source")) {
    await simulateDrag(source, target, { dataTransfer, targetCoordinates });
    return;
  }
  await startDrag(source, { dataTransfer });
  await dragOver(target, { dataTransfer, coordinates: targetCoordinates });
  await dragEvent(target, "drop", { dataTransfer, ...targetCoordinates });
  await dragEvent(source, "dragend", { dataTransfer, ...targetCoordinates });
}

/** Allow autonomous scrolling to run without dispatching additional drag events. */
async function waitForScrollFrames() {
  for (let frame = 0; frame < 12; frame++) {
    await new Promise((resolve) => requestAnimationFrame(resolve));
  }
}

async function renderScrollableBoard(context) {
  const fabricators = new BoardsFabricators(getOwner(context));
  context.column.cards = Array.from({ length: 12 }, (_, index) =>
    fabricators.card({ id: 201 + index, column_id: 20, board_id: 1 })
  );
  await context.renderBoard();
  const container = find(cardsSelector);
  // Give both edge zones room in the scaled fixture, with genuine DOM overflow.
  container.style.height = "400px";
  container.style.flex = "none";
  container.style.overflowY = "auto";
  container.style.overflowAnchor = "none";
  return container;
}

function scrollEdgePoint(container, edge) {
  const rect = container.getBoundingClientRect();
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height * (edge === "top" ? 0.01 : 0.99),
  };
}

module(
  "Integration | Component | BoardsColumn | drag oracle",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const fabricators = new BoardsFabricators(getOwner(this));
      this.board = fabricators.board({ id: 1 });
      this.sourceColumn = fabricators.column({ id: 10 });
      this.column = fabricators.column({ id: 20 });
      this.sourceColumn.cards = [
        fabricators.card({ id: 101, column_id: 10, board_id: 1 }),
      ];
      this.column.cards = [201, 202, 203].map((id) => {
        const card = fabricators.card({ id, column_id: 20, board_id: 1 });
        card.recency_at = new Date().toISOString();
        return card;
      });
      this.calls = [];
      this.canWrite = true;
      this.handler = (...args) => this.calls.push(args);
      this.onDragStart = (data) => this.set("dragData", data);
      this.onDragEnd = () => this.set("dragData", null);
      this.noop = () => {};
      this.renderBoard = () =>
        render(
          <template>
            <div class="discourse-boards-board">
              <BoardsColumn
                @board={{this.board}}
                @canWrite={{this.canWrite}}
                @column={{this.sourceColumn}}
                @dragData={{this.dragData}}
                @onDragEnd={{this.onDragEnd}}
                @onDragStart={{this.onDragStart}}
                @onDrop={{this.handler}}
                @onPromoteToTopic={{this.noop}}
              />
              <BoardsColumn
                @board={{this.board}}
                @canWrite={{this.canWrite}}
                @column={{this.column}}
                @dragData={{this.dragData}}
                @onDragEnd={{this.onDragEnd}}
                @onDragStart={{this.onDragStart}}
                @onDrop={{this.handler}}
                @onPromoteToTopic={{this.noop}}
              />
            </div>
          </template>
        );
    });

    for (const [label, fraction, afterCardId] of [
      ["above", 0.25, 201],
      ["at", 0.5, 201],
      ["below", 0.75, 202],
    ]) {
      test(`boards-dnd-oracle: midpoint ${label} uses the last preceding card`, async function (assert) {
        await this.renderBoard();
        const dataTransfer = new DataTransfer();
        await startDrag(cardSelector(101), { dataTransfer });
        const target = find(cardSelector(202)).hasAttribute("data-drop-target")
          ? cardSelector(202)
          : columnSelector;
        await dragOver(target, {
          dataTransfer,
          coordinates: pointOnCard(202, fraction),
        });
        // The legacy spacer changes layout; measure the actual drop geometry anew.
        await dragEvent(target, "drop", {
          dataTransfer,
          ...pointOnCard(202, fraction),
        });
        await dragEvent(cardSelector(101), "dragend", {
          dataTransfer,
          ...centerOf(columnSelector),
        });
        assert.deepEqual(
          this.calls,
          [[101, 20, afterCardId, 10]],
          "onDrop is called once with exactly (cardId, toColumnId, afterCardId, fromColumnId)"
        );
      });
    }

    test("boards-dnd-oracle: drop above every midpoint inserts at the head", async function (assert) {
      await this.renderBoard();
      const target = find(cardSelector(201)).hasAttribute("data-drop-target")
        ? cardSelector(201)
        : columnSelector;
      const dataTransfer = new DataTransfer();
      await startDrag(cardSelector(101), { dataTransfer });
      await dragOver(target, {
        dataTransfer,
        coordinates: pointOnCard(201, 0.1),
      });
      await dragEvent(target, "drop", {
        dataTransfer,
        ...pointOnCard(201, 0.1),
      });
      await dragEvent(cardSelector(101), "dragend", {
        dataTransfer,
        ...centerOf(columnSelector),
      });
      assert.deepEqual(
        this.calls,
        [[101, 20, null, 10]],
        "head has no predecessor"
      );
      assert
        .dom(indicatorSelector)
        .doesNotExist("drop tears down the indicator");
    });

    test("boards-dnd-oracle: dragged card is excluded from predecessors", async function (assert) {
      await this.renderBoard();
      const dataTransfer = new DataTransfer();
      await startDrag(cardSelector(202), { dataTransfer });
      await dragOver(columnSelector, { dataTransfer });
      const sourceRect = find(cardSelector(202)).getBoundingClientRect();
      const previousRect = find(cardSelector(201)).getBoundingClientRect();
      const nextRect = find(cardSelector(203)).getBoundingClientRect();
      const coordinates = {
        clientX: nextRect.left + nextRect.width / 2,
        // The hidden source has no layout slot; aim between the surviving cards.
        clientY: (previousRect.bottom + nextRect.top) / 2,
      };
      assert.true(
        coordinates.clientY > sourceRect.top + sourceRect.height / 2,
        "pointer is below the dragged card midpoint, exposing accidental self-inclusion"
      );
      await dragOver(columnSelector, { dataTransfer, coordinates });
      const previousDropRect = find(cardSelector(201)).getBoundingClientRect();
      const nextDropRect = find(cardSelector(203)).getBoundingClientRect();
      assert.true(
        coordinates.clientY >
          previousDropRect.top + previousDropRect.height / 2,
        "pointer is strictly below the previous sibling midpoint"
      );
      assert.true(
        coordinates.clientY < nextDropRect.top + nextDropRect.height / 2,
        "pointer is above the next sibling midpoint"
      );
      await dragEvent(columnSelector, "drop", { dataTransfer, ...coordinates });
      await dragEvent(cardSelector(202), "dragend", {
        dataTransfer,
        ...coordinates,
      });
      assert.deepEqual(
        this.calls,
        [[202, 20, 201, 20]],
        "predecessor is the previous sibling, never the dragged card"
      );
    });

    test("boards-dnd-oracle: recency refuses intra-column reorder", async function (assert) {
      this.column.default_sort = "recency";
      await this.renderBoard();
      const dataTransfer = new DataTransfer();
      await startDrag(cardSelector(202), { dataTransfer });
      await dragOver(columnSelector, { dataTransfer });
      assert
        .dom(indicatorSelector)
        .doesNotExist("recency has no reorder indicator");
      await dragEvent(columnSelector, "drop", {
        dataTransfer,
        ...centerOf(columnSelector),
      });
      await dragEvent(cardSelector(202), "dragend", {
        dataTransfer,
        ...centerOf(columnSelector),
      });
      assert.deepEqual(
        this.calls,
        [],
        "recency rejects a drop from the same column"
      );
      assert
        .dom(indicatorSelector)
        .doesNotExist("rejected drop leaves no indicator");
    });

    test("boards-dnd-oracle: recency accepts cross-column drops without a predecessor", async function (assert) {
      this.column.default_sort = "recency";
      await this.renderBoard();
      await completeDrag(
        cardSelector(101),
        columnSelector,
        pointOnCard(203, 0.9)
      );
      assert.deepEqual(
        this.calls,
        [[101, 20, null, 10]],
        "recency ignores pointer order for cross-column drops"
      );
    });

    test("boards-dnd-oracle: indicator placement survives internal leave and clears on exit", async function (assert) {
      await this.renderBoard();
      const dataTransfer = new DataTransfer();
      await startDrag(cardSelector(101), { dataTransfer });
      const coordinates = pointOnCard(201, 0.1);
      const target = find(cardSelector(201)).hasAttribute("data-drop-target")
        ? cardSelector(201)
        : columnSelector;
      await dragOver(target, { dataTransfer, coordinates });
      assert.strictEqual(
        findAll(indicatorSelector).length,
        1,
        "one live indicator is shown"
      );
      const indicator = find(indicatorSelector);
      const isSpacer = indicator?.matches(
        ".discourse-boards-column__drop-indicator"
      );
      assert.true(
        isSpacer
          ? indicator.nextElementSibling === find(cardSelector(201))
          : find(cardSelector(201)).classList.contains("--drag-above"),
        "indicator precedes the first card"
      );
      assert.true(
        isSpacer
          ? Math.abs(
              parseFloat(indicator.style.height) - this.dragData.cardHeight
            ) < 0.01
          : true,
        "a spacer reserves the measured dragged height (CSS line indicators need no spacer)"
      );
      await dragEvent(target, "dragleave", {
        dataTransfer,
        ...coordinates,
        relatedTarget: find(cardSelector(202)),
      });
      assert
        .dom(indicatorSelector)
        .exists("moving within the column preserves the indicator");
      await dragEvent(columnSelector, "dragleave", {
        dataTransfer,
        ...coordinates,
        relatedTarget: document.body,
      });
      await dragEvent(document.body, "dragenter", {
        dataTransfer,
        clientX: 0,
        clientY: 0,
      });
      assert
        .dom(indicatorSelector)
        .doesNotExist("leaving the column removes the indicator");
      await dragEvent(cardSelector(101), "dragend", {
        dataTransfer,
        ...coordinates,
      });
    });

    for (const finish of ["drop", "leave"]) {
      test(`boards-dnd-oracle: empty message restores after ${finish}`, async function (assert) {
        this.column.cards = [];
        await this.renderBoard();
        assert.dom(emptySelector).isVisible("empty message starts visible");
        const dataTransfer = new DataTransfer();
        await startDrag(cardSelector(101), { dataTransfer });
        await dragOver(columnSelector, { dataTransfer });
        assert
          .dom(indicatorSelector)
          .exists("empty column shows a drop indicator");
        assert
          .dom(emptySelector)
          .isNotVisible("empty message hides during hover");
        const coordinates = centerOf(columnSelector);
        await dragEvent(
          columnSelector,
          finish === "drop" ? "drop" : "dragleave",
          {
            dataTransfer,
            ...coordinates,
            relatedTarget: document.body,
          }
        );
        if (finish === "leave") {
          await dragEvent(document.body, "dragenter", {
            dataTransfer,
            clientX: 0,
            clientY: 0,
          });
        }
        assert.dom(indicatorSelector).doesNotExist("indicator is removed");
        assert.dom(emptySelector).isVisible("empty message is restored");
        await dragEvent(cardSelector(101), "dragend", {
          dataTransfer,
          ...coordinates,
        });
        assert.deepEqual(
          this.calls,
          finish === "drop" ? [[101, 20, null, 10]] : [],
          "only an actual drop invokes the callback"
        );
      });
    }

    for (const edge of ["top", "bottom"]) {
      test(`boards-dnd-oracle: auto-scroll engages near the ${edge} edge and stops at its limit`, async function (assert) {
        const container = await renderScrollableBoard(this);
        const dataTransfer = new DataTransfer();
        const source = cardSelector(101);
        await startDrag(source, { dataTransfer });
        try {
          await dragOver(cardsSelector, {
            dataTransfer,
            coordinates: centerOf(cardsSelector),
          });
          container.scrollTop =
            (container.scrollHeight - container.clientHeight) / 2;
          const initialScrollTop = container.scrollTop;
          assert.true(
            initialScrollTop > 0,
            "fixture has genuine vertical overflow"
          );
          await waitForScrollFrames();
          assert.strictEqual(
            container.scrollTop,
            initialScrollTop,
            "hovering at the center does not scroll"
          );

          const coordinates = scrollEdgePoint(container, edge);
          await dragOver(cardsSelector, { dataTransfer, coordinates });
          await waitUntil(
            () =>
              edge === "top"
                ? container.scrollTop < initialScrollTop
                : container.scrollTop > initialScrollTop,
            {
              timeout: 5000,
              timeoutMessage: `auto-scroll did not engage near the ${edge} edge`,
            }
          );
          assert.true(
            edge === "top"
              ? container.scrollTop < initialScrollTop
              : container.scrollTop > initialScrollTop,
            "the edge hover scrolls in the intended direction"
          );
          await waitUntil(
            () =>
              edge === "top"
                ? container.scrollTop === 0
                : Math.abs(
                    container.scrollHeight -
                      container.clientHeight -
                      container.scrollTop
                  ) < 1,
            {
              timeout: 5000,
              timeoutMessage: `auto-scroll did not reach the ${edge} limit`,
            }
          );
          const atLimit = container.scrollTop;
          await waitForScrollFrames();
          assert.strictEqual(
            container.scrollTop,
            atLimit,
            "scroll position remains at the limit while the drag stays at the edge"
          );
        } finally {
          await dragEvent(source, "dragend", {
            dataTransfer,
            ...centerOf(cardsSelector),
          });
        }
      });
    }

    test("boards-dnd-oracle: auto-scroll stops when the drag ends", async function (assert) {
      const container = await renderScrollableBoard(this);
      const dataTransfer = new DataTransfer();
      const source = cardSelector(101);
      await startDrag(source, { dataTransfer });
      try {
        await dragOver(cardsSelector, {
          dataTransfer,
          coordinates: centerOf(cardsSelector),
        });
        container.scrollTop =
          (container.scrollHeight - container.clientHeight) / 2;
        const initialScrollTop = container.scrollTop;
        await dragOver(cardsSelector, {
          dataTransfer,
          coordinates: scrollEdgePoint(container, "bottom"),
        });
        await waitUntil(() => container.scrollTop > initialScrollTop, {
          timeout: 5000,
          timeoutMessage: "auto-scroll did not engage before dragend",
        });
        assert.true(
          container.scrollTop > initialScrollTop,
          "auto-scroll is active before ending the drag"
        );
      } finally {
        await dragEvent(source, "dragend", {
          dataTransfer,
          ...centerOf(cardsSelector),
        });
      }
      // Stay away from the limit so browser clamping cannot conceal a leaked loop.
      container.scrollTop =
        (container.scrollHeight - container.clientHeight) / 2;
      const stoppedScrollTop = container.scrollTop;
      assert.true(
        stoppedScrollTop > 0,
        "cleanup is observed inside a scrollable range"
      );
      await waitForScrollFrames();
      assert.strictEqual(
        container.scrollTop,
        stoppedScrollTop,
        "dragend stops further scrolling even with room to scroll"
      );
    });

    test("boards-dnd-oracle: source registration follows write permission", async function (assert) {
      await this.renderBoard();
      assert
        .dom(cardSelector(101))
        .hasAttribute(
          "data-drag-source",
          "",
          "writable card is a registered drag source"
        );
      this.set("canWrite", false);
      await settled();
      assert
        .dom(cardSelector(101))
        .doesNotHaveAttribute(
          "data-drag-source",
          "read-only card is not a registered drag source"
        );
      this.set("canWrite", true);
      await settled();
      assert
        .dom(cardSelector(101))
        .hasAttribute(
          "data-drag-source",
          "",
          "restoring write permission registers the source again"
        );
    });
  }
);
