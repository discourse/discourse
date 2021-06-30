import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "personal",
  "private-messages-unread",
  null /* no message bus notifications */
);
