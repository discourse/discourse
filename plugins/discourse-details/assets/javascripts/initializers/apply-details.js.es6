import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";

function initializeDetails(api) {
  api.decorateCooked(($elem) => $("details", $elem), {
    id: "discourse-details",
  });

  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      action: "insertDetails",
      icon: "caret-right",
      label: "details.title",
    };
  });

  api.modifyClass("controller:composer", {
    pluginId: "discourse-details",
    actions: {
      insertDetails() {
        this.toolbarEvent.applySurround(
          "\n" + `[details="${I18n.t("composer.details_title")}"]` + "\n",
          "\n[/details]\n",
          "details_text",
          { multiline: false }
        );
      },
    },
  });
}

export default {
  name: "apply-details",

  initialize() {
    withPluginApi("0.8.7", initializeDetails);
  },
};
