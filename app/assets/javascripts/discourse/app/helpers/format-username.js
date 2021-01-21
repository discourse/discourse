import { formatUsername } from "discourse/lib/utilities";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound("format-username", formatUsername);
