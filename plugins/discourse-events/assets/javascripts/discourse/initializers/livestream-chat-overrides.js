import { withPluginApi } from "discourse/lib/plugin-api";
import ResponsiveLivestreamChatIcon from "../components/livestream/responsive-livestream-chat-icon";

function showCustomBBCode(isGoing = false) {
  // show the content within the [preview] tag if the user is not going to the event
  document.querySelectorAll(".cooked .preview").forEach((e) => {
    e.style.setProperty("display", !isGoing ? "block" : "none", "important");
  });

  // show the content within the [hidden] tag if the user is going to the event
  document.querySelectorAll(".cooked .hidden").forEach((e) => {
    e.style.setProperty("display", isGoing ? "block" : "none", "important");
  });
}

async function onAcceptInvite({ status }) {
  if (status === "going") {
    showCustomBBCode(true);
    document.body.classList.add("confirmed-event-assistance");
  } else if (status !== "going") {
    showCustomBBCode(false);
    document.body.classList.remove("confirmed-event-assistance");
  }
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
      onAcceptInvite({
        ...data,
      });
    });
  });

  api.headerIcons.add("livestream", ResponsiveLivestreamChatIcon, {
    before: "chat",
  });

  api.onPageChange((url) => {
    const store = container.lookup("service:store");
    const topic = container.lookup("controller:topic");
    const allowedPaths =
      siteSettings.livestream_embeddable_chat_allowed_paths.split("|");

    // non livestream topics
    if (
      allowedPaths.every(
        (path) => !url.includes(path) && !url.startsWith(path)
      ) ||
      !topic?.model?.chat_channel_id
    ) {
      return false;
    }

    updateEventStylesByStatus(topic, store, currentUser);
  });
}

async function updateEventStylesByStatus(topic, store, currentUser) {
  let isGoing;
  try {
    const topicPost = parseInt(
      document.getElementById("post_1").dataset.postId,
      10
    );
    const attendees = await store.findAll("discourse-post-event-invitee", {
      undefined,
      post_id: topicPost,
      type: "going",
    });
    isGoing = attendees.content.some(
      (attendee) => attendee.user.id === currentUser.id
    );
    showCustomBBCode(isGoing);
  } catch {
    // no event found
  } finally {
    if (!isGoing) {
      document.body.classList.remove("confirmed-event-assistance");
    } else {
      document.body.classList.add("confirmed-event-assistance");
    }
  }
}

export default {
  name: "discourse-calendar-livestream-chat-sidebar",
  initialize(container) {
    withPluginApi((api) => {
      overrideChat(api, container);
    });
  },
};
