import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { registerTooltip } from "discourse/lib/tooltip";

function initializeDiscourseLocalDates(api) {
  api.decorateCooked($elem => {
    $(".discourse-local-date", $elem).applyLocalDates();
    registerTooltip($(".discourse-local-date", $elem));
  });

  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      action: "insertDiscourseLocalDate",
      icon: "globe",
      label: "discourse_local_dates.title"
    };
  });

  api.modifyClass("controller:composer", {
    actions: {
      insertDiscourseLocalDate() {
        showModal("discourse-local-dates-create-modal").setProperties({
          toolbarEvent: this.get("toolbarEvent")
        });
      }
    }
  });
}

export default {
  name: "discourse-local-dates",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_local_dates_enabled) {
      withPluginApi("0.8.8", initializeDiscourseLocalDates);
    }
  }
};
