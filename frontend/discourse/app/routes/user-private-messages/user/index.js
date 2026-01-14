import createPMRoute, {
  INBOX_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("user", "private-messages", INBOX_FILTER);
