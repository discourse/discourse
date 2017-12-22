export function displayPollBuilderButton() {
  visit("/");
  click("#create-topic");
  click(".d-editor-button-bar .options");
  selectKit(".toolbar-popup-menu-options").expand();
}
