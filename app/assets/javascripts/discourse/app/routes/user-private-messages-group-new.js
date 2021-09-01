import createPMRoute from "discourse/routes/build-private-messages-group-route";
import { NEW_FILTER } from "discourse/routes/build-private-messages-route";

export default createPMRoute("group", NEW_FILTER);
