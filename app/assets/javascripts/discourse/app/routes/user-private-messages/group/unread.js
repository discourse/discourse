import createPMRoute from "discourse/routes/build-private-messages-group-route";
import { UNREAD_FILTER } from "discourse/routes/build-private-messages-route";

export default createPMRoute("group", UNREAD_FILTER);
