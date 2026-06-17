import { withPluginApi } from "discourse/lib/plugin-api";
import LivestreamZoomEntry from "../components/livestream/zoom-entry";
import { isSupportedZoomJoinUrl } from "../lib/zoom-url";

function isLivestreamTopic(topic) {
  return (
    topic?.tags?.some?.((tag) => {
      const tagName = typeof tag === "string" ? tag : tag.name;
      return tagName === "livestream";
    }) || false
  );
}

export default {
  name: "discourse-calendar-livestream-zoom-decorator",

  initialize() {
    withPluginApi((api) => {
      api.decorateCookedElement(
        (element, helper) => {
          const post = helper.getModel();

          if (
            !post?.firstPost ||
            !isLivestreamTopic(post.topic) ||
            !post?.topic?.chat_channel_id ||
            !isSupportedZoomJoinUrl(post?.event?.url)
          ) {
            return;
          }

          const postEvent = element.querySelector(".discourse-post-event");
          if (!postEvent) {
            return;
          }

          const wrapper = document.createElement("div");
          wrapper.className =
            "discourse-calendar-livestream-zoom-entry-container";
          postEvent.after(wrapper);

          helper.renderGlimmer(wrapper, LivestreamZoomEntry, {
            topic: post.topic,
            zoomUrl: post.event.url,
          });
        },
        { id: "discourse-calendar-livestream-zoom-decorator", onlyStream: true }
      );
    });
  },
};
