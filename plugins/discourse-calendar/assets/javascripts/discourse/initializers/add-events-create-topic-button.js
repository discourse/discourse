import { withPluginApi } from "discourse/lib/plugin-api";

function eventsCategoryIds(siteSettings) {
  return (siteSettings.events_calendar_categories || "")
    .split("|")
    .filter(Boolean)
    .map((id) => parseInt(id, 10));
}

function isEventsCategoryContext(context, currentUser, siteSettings) {
  if (!currentUser?.can_create_discourse_post_event) {
    return false;
  }
  const categoryId = context.category?.id;
  if (!categoryId) {
    return false;
  }
  return eventsCategoryIds(siteSettings).includes(categoryId);
}

function initializeEventsCreateTopicButton(api, siteSettings) {
  const currentUser = api.getCurrentUser();

  api.registerValueTransformer("create-topic-label", ({ value, context }) => {
    if (value !== "topic.create") {
      return value;
    }
    if (!isEventsCategoryContext(context, currentUser, siteSettings)) {
      return value;
    }
    return "discourse_post_event.new_event";
  });

  api.registerValueTransformer("create-topic-icon", ({ value, context }) => {
    if (!isEventsCategoryContext(context, currentUser, siteSettings)) {
      return value;
    }
    return "far-calendar-plus";
  });
}

export default {
  name: "add-events-create-topic-button",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    withPluginApi((api) =>
      initializeEventsCreateTopicButton(api, siteSettings)
    );
  },
};
