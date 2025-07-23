import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  const gistService = api.container.lookup("service:gists");

  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value, context }) => {
      const shouldShow =
        gistService.preference === "table-ai" && gistService.shouldShow;

      if (context.topic.get("ai_topic_gist") && shouldShow) {
        value.push("excerpt-expanded");
      }

      return value;
    }
  );
});
