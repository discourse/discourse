import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeDiscourseCronos(api) {
  api.decorateCooked($elem => {
    $(".discourse-cronos", $elem).cronos();
  });

  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      action: "insertDiscourseCronos",
      icon: "globe",
      label: "discourse_cronos.title"
    };
  });

  api.modifyClass('controller:composer', {
    actions: {
      insertDiscourseCronos() {
        showModal("discourse-cronos-create-modal").setProperties({
          toolbarEvent: this.get("toolbarEvent")
        });
      }
    }
  });
}

export default {
  name: "discourse-cronos",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_cronos_enabled) {
      withPluginApi("0.8.8", initializeDiscourseCronos);
    }
  }
};
