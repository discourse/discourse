import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "new",
  "private-messages-all-new",
  null /* no message bus notifications */
);
