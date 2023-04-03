import createPMRoute from "discourse/routes/build-private-messages-group-route";
import { INBOX_FILTER } from "discourse/routes/build-private-messages-route";

export default createPMRoute("group", INBOX_FILTER);
