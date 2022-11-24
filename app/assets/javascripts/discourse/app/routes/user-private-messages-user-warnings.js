import createPMRoute from "discourse/routes/build-private-messages-route";

export const VIEW_NAME_WARNINGS = "warnings";

export default createPMRoute(
  VIEW_NAME_WARNINGS,
  "private-messages-warnings",
  null /* no message bus notifications */
);
