export const customUserNavMessagesDropdownRows = [];

export function registerCustomUserNavMessagesDropdownRow(
  routeName,
  name,
  icon
) {
  customUserNavMessagesDropdownRows.push({ routeName, name, icon });
}

export function resetCustomUserNavMessagesDropdownRows() {
  customUserNavMessagesDropdownRows.length = 0;
}
