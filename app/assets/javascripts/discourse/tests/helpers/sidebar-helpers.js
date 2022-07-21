import { click } from "@ember/test-helpers";

export async function undockSidebar() {
  await click("button.sidebar-footer-actions-dock-toggle");
}
