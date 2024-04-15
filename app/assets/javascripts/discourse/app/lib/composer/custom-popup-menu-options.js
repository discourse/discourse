export const customPopupMenuOptions = [];

export function clearPopupMenuOptions() {
  customPopupMenuOptions.length = 0;
}

export function addPopupMenuOption(option) {
  customPopupMenuOptions.push(option);
}
