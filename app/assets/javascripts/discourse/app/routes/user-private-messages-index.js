import createPMRoute, {
  INBOX_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("all", "private-messages-all", INBOX_FILTER);
