import { i18n } from "discourse-i18n";

export const itemLabel = (item) =>
  item.label || i18n("form_definition.untitled");

export function reorder(set, path, move) {
  set(path, move.proposedToItems);
}

export function remove(set, path, items, item) {
  set(
    path,
    items.filter((other) => other.id !== item.id)
  );
}
