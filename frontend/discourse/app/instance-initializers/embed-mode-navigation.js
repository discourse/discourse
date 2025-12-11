import EmbedMode from "discourse/lib/embed-mode";
import { TOPIC_URL_REGEXP } from "discourse/lib/url";

export default {
  initialize(owner) {
    if (!EmbedMode.enabled) {
      return;
    }

    const router = owner.lookup("service:router");
    const currentTopicMatch = TOPIC_URL_REGEXP.exec(window.location.pathname);
    const currentTopicId = currentTopicMatch ? currentTopicMatch[2] : null;

    router.on("routeWillChange", (transition) => {
      // Skip the initial page load transition (no previous route)
      if (!transition.from) {
        return;
      }

      const to = transition.to;
      if (!to?.name) {
        return;
      }

      // Allow navigation within the same topic
      if (to.name.startsWith("topic.") && to.params?.id === currentTopicId) {
        return;
      }

      // Block all other navigations and open in new window
      let destUrl;
      let params = {};

      for (let r = to; r; r = r.parent) {
        params = { ...params, ...r.params };
      }

      try {
        if (to.name === "topic.fromParamsNear") {
          destUrl = router.urlFor("topic.fromParams", params);
          destUrl += `/${params.nearPost}`;
        } else if (Object.keys(params).length > 0) {
          destUrl = router.urlFor(to.name, params);
        } else {
          destUrl = router.urlFor(to.name);
        }
      } catch {
        destUrl = "/";
      }

      transition.abort();
      window.open(destUrl, "_blank");
    });
  },
};
