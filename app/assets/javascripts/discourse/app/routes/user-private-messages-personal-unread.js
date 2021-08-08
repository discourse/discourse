import {
  UNREAD_FILTER,
  default as createPMRoute,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("user", "private-messages-unread", UNREAD_FILTER);
