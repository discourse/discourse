import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "add-topic-list-class",

  initialize() {
    withPluginApi("1.39.0", (api) => {
      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          if (context.topic.get("has_accepted_answer")) {
            value.push("status-solved");
          }
          return value;
        }
      );
    });
  },
};
