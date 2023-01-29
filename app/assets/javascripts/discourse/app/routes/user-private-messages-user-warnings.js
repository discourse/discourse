import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "warnings",
  "private-messages-warnings",
  null /* no message bus notifications */
);
