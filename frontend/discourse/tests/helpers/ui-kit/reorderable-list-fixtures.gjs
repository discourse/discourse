import { find, findAll } from "@ember/test-helpers";
import DMenus from "discourse/float-kit/components/d-menus";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

/**
 * Shared fixtures for the `DReorderableList` suites.
 *
 * The suite is split across several files by concern, and they describe the
 * same list, so the rows, the shell and the drag assertions live here rather
 * than once per file.
 */

export const noop = () => {};
export const INDEX_KEY = "@index";
export const label = (item) => item.name ?? String(item);

/** Two movable rows above two that are frozen, as a grouped catalogue renders. */
export function mixedItems() {
  return [
    { id: "alpha", name: "Alpha" },
    { id: "bravo", name: "Bravo" },
    { id: "charlie", name: "Charlie" },
    { id: "delta", name: "Delta" },
  ];
}

export const isMovable = (item) => item.id === "alpha" || item.id === "bravo";

export function objectItems() {
  return [
    { id: "alpha", identity: { value: "alpha-key" }, name: "Alpha" },
    { id: "bravo", identity: { value: "bravo-key" }, name: "Bravo" },
    { id: "charlie", identity: { value: "charlie-key" }, name: "Charlie" },
  ];
}

/**
 * The plain list most tests exercise: object rows keyed by id, one span each.
 *
 * Only the collection and the move handler vary, so a test that cares about
 * neither the markup nor the arguments says so by using this instead of
 * repeating the shell.
 */
export const List = <template>
  <DMenus />
  <DReorderableList
    @items={{@items}}
    @key="id"
    @label={{label}}
    @onMove={{@onMove}}
  >
    <:row as |item|>
      <span data-test-item={{item.id}}>{{item.name}}</span>
    </:row>
  </DReorderableList>
</template>;

export const MENU_SELECTOR =
  '[data-identifier="reorderable-list-move"] .dropdown-menu';

export function renderedItemOrder(root = "") {
  const prefix = root ? `${root} ` : "";
  return findAll(`${prefix}[data-test-item]`).map(
    (element) => element.dataset.testItem
  );
}

export function dropCoordinates(targetSelector, position) {
  const rect = find(targetSelector).getBoundingClientRect();
  const fraction = position === "before" ? 0.25 : 0.75;
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height * fraction,
  };
}

export function assertDragReady(assert, source, target) {
  assert
    .dom(source)
    .hasAttribute(
      "data-drag-source",
      "",
      "the row is the registered drag source, so it is what a drop receives and what the preview photographs"
    );
  assert
    .dom(`${source} .d-reorderable-list__handle`)
    .hasAttribute(
      "draggable",
      "true",
      "and the handle is where the drag may begin"
    );
  assert
    .dom(target)
    .hasAttribute(
      "data-drop-target",
      "",
      "the destination row is registered for drops"
    );
}
