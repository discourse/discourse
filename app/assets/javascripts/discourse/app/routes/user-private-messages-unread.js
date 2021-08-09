import {
  UNREAD_FILTER,
  default as createPMRoute,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "all",
  "private-messages-all-unread",
  UNREAD_FILTER
);
