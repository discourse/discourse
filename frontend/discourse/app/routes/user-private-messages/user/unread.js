import createPMRoute, {
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("user", "private-messages-unread", UNREAD_FILTER);
