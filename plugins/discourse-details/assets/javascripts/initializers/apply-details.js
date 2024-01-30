import $ from "jquery";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "discourse-i18n";

function initializeDetails(api) {
  api.decorateCooked(($elem) => $("details", $elem), {
    id: "discourse-details",
  });

  api.addComposerToolbarPopupMenuOption({
    action: function (toolbarEvent) {
      toolbarEvent.applySurround(
        "\n" + `[details="${I18n.t("composer.details_title")}"]` + "\n",
        "\n[/details]\n",
        "details_text",
        { multiline: false }
      );
    },
    icon: "caret-right",
    label: "details.title",
  });
}

export default {
  name: "apply-details",

  initialize() {
    withPluginApi("1.14.0", initializeDetails);
  },
};
