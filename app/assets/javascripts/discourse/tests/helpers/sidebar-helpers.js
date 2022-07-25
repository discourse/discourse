import I18n from "I18n";

import { click } from "@ember/test-helpers";

export async function undockSidebar() {
  await click(
    `button.sidebar-footer-actions-dock-toggle[title="${I18n.t(
      "sidebar.unpin"
    )}"]`
  );
}
