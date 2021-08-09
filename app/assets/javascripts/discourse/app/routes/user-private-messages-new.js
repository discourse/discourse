import {
  NEW_FILTER,
  default as createPMRoute,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute("all", "private-messages-all-new", NEW_FILTER);
