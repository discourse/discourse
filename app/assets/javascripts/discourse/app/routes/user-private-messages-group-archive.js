import createPMRoute from "discourse/routes/build-private-messages-group-route";
import { ARCHIVE_FILTER } from "discourse/routes/build-private-messages-route";

export default createPMRoute("group", ARCHIVE_FILTER);
