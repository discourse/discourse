import { registerUnbound } from "discourse-common/lib/helpers";
import getUrl from "discourse-common/lib/get-url";

registerUnbound("get-url", value => getUrl(value));
