import { registerUnbound } from "discourse-common/lib/helpers";
import { formatUsername } from "discourse/lib/utilities";

export default registerUnbound("format-username", formatUsername);
