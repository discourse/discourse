import { click, visit } from "@ember/test-helpers";

export async function displayPollBuilderButton() {
  await visit("/");
  await click("#create-topic");
  await click(".toolbar-menu__options-trigger");
}
