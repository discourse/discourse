import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  api.modifyClass("component:search-result-entry", {
    pluginId: "discourse-ai",

    classNameBindings: ["bulkSelectEnabled", "post.generatedByAi:ai-result"],
  });
});
