import { withPluginApi } from "discourse/lib/plugin-api";
import ResponsiveLivestreamChatIcon from "../components/livestream/responsive-livestream-chat-icon";

const GOING = "going";

function showCustomBBCode(element, isGoing) {
  // show the content within the [preview] tag if the user is not going to the event
  element.querySelectorAll(".preview").forEach((e) => {
    e.style.setProperty("display", !isGoing ? "block" : "none", "important");
  });

  // show the content within the [hidden] tag if the user is going to the event
  element.querySelectorAll(".hidden").forEach((e) => {
    e.style.setProperty("display", isGoing ? "block" : "none", "important");
  });
}

function attendanceStatus(container) {
  const router = container.lookup("service:router");

  if (!router.currentRouteName?.startsWith("topic.")) {
    return undefined;
  }

  return container.lookup("controller:topic").model
    ?.event_watching_invitee_status;
}

function updateEventStyles(container) {
  const status = attendanceStatus(container);

  if (status === undefined) {
    document.body.classList.remove("confirmed-event-assistance");
    return;
  }

  document.body.classList.toggle(
    "confirmed-event-assistance",
    status === GOING
  );

  document
    .querySelectorAll(".cooked")
    .forEach((cooked) => showCustomBBCode(cooked, status === GOING));
}

function onAttendanceChange(container, { status }) {
  // the topic is serialized once per visit, so the answer is kept in sync to
  // survive later navigation within the topic
  container
    .lookup("controller:topic")
    .model?.set("event_watching_invitee_status", status ?? null);

  updateEventStyles(container);
}

function overrideChat(api, container) {
  const siteSettings = container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();
  const chatService = container.lookup("service:chat");
  const appEvents = container.lookup("service:appEvents");

  if (!currentUser || !siteSettings.chat_enabled || !chatService?.userCanChat) {
    return;
  }

  const events = [
    "calendar:update-invitee-status",
    "calendar:create-invitee-status",
    "calendar:invitee-left-event",
  ];

  events.forEach((event) => {
    appEvents.on(event, (data) => {
      onAttendanceChange(container, { ...data });
    });
  });

  api.headerIcons.add("livestream", ResponsiveLivestreamChatIcon, {
    before: "chat",
  });

  api.onPageChange(() => {
    updateEventStyles(container);
  });

  // posts entered further down the stream are cooked after the styles are
  // applied, so they are decorated as they render
  api.decorateCookedElement(
    (element) => {
      const status = attendanceStatus(container);

      if (status !== undefined) {
        showCustomBBCode(element, status === GOING);
      }
    },
    { onlyStream: true }
  );
}

function collapseTimeline(api, container) {
  api.registerValueTransformer(
    "topic-navigation-render-timeline",
    ({ value }) =>
      container.lookup("service:embeddable-chat").isChatDocked ? false : value
  );
}

export default {
  name: "discourse-calendar-livestream-chat-sidebar",
  initialize(container) {
    withPluginApi((api) => {
      overrideChat(api, container);
      collapseTimeline(api, container);
    });
  },
};
