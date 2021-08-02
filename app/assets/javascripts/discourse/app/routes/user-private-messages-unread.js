import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "unread",
  "private-messages-all-unread",
  null /* no message bus notifications */
);
