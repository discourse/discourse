export default {
  name: "initialize-data-explorer",
  initialize(container) {
    container.lookup("service:store").addPluralization("query", "queries");
  },
};
