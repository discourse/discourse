const actions = new Map();

export function addBulkDropdownAction(name, action) {
  actions.set(name, action);
}

export function bulkDropdownAction(name) {
  return actions.get(name);
}
