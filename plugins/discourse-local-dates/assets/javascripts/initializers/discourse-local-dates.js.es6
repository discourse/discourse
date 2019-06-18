import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeDiscourseLocalDates(api) {
  api.decorateCooked(
    $elem => {
      $(".discourse-local-date", $elem).applyLocalDates();
    },
    { id: "discourse-local-date" }
  );

  api.onToolbarCreate(toolbar => {
    toolbar.addButton({
      title: "discourse_local_dates.title",
      id: "local-dates",
      group: "extras",
      icon: "calendar-alt",
      sendAction: event =>
        toolbar.context.send("insertDiscourseLocalDate", event)
    });
  });

  api.modifyClass("component:d-editor", {
    actions: {
      insertDiscourseLocalDate(toolbarEvent) {
        showModal("discourse-local-dates-create-modal").setProperties({
          toolbarEvent
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
