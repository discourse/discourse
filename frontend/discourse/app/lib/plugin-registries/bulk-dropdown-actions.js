export const customBulkActions = {};

export function addBulkDropdownAction(name, customAction) {
  customBulkActions[name] = customAction;
}
