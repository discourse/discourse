import { registerRawHelper } from "discourse/lib/helpers";
import { formatUsername } from "discourse/lib/utilities";

export default formatUsername;
registerRawHelper("format-username", formatUsername);
