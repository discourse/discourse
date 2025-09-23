import createPMRoute, {
  NEW_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("user", "private-messages-new", NEW_FILTER);
