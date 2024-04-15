import { formatUsername } from "discourse/lib/utilities";
import { registerRawHelper } from "discourse-common/lib/helpers";

export default formatUsername;
registerRawHelper("format-username", formatUsername);
