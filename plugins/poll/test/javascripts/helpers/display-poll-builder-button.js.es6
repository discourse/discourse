import selectKit from "helpers/select-kit-helper";

export async function displayPollBuilderButton() {
  await visit("/");
  await click("#create-topic");
  await click(".d-editor-button-bar .options");
  await selectKit(".toolbar-popup-menu-options").expand();
}
