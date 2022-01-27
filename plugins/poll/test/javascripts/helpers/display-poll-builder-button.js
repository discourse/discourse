import selectKit from "discourse/tests/helpers/select-kit-helper";
import { click, visit } from "@ember/test-helpers";

export async function displayPollBuilderButton() {
  await visit("/");
  await click("#create-topic");
  await click(".d-editor-button-bar .options");
  await selectKit(".toolbar-popup-menu-options").expand();
}
