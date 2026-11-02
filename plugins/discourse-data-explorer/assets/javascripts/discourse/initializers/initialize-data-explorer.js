import { QueriesSchema } from "../data/schemas/queries.js";

export default {
  name: "initialize-data-explorer",
  initialize(container) {
    container.lookup("service:store").addPluralization("query", "queries");

    if (container.lookup("service:current-user")?.admin) {
      container
        .lookup("service:warp-store")
        .schema.registerResources([QueriesSchema]);
    }
  },
};
