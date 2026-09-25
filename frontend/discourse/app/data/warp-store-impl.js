import "@warp-drive/ember/install";
import { JSONAPICache } from "@warp-drive/json-api";
import { useLegacyStore } from "@warp-drive/legacy";
import discourseRestHandler from "discourse/data/handlers/discourse-rest";
import { schemas } from "discourse/data/schemas";
import { registerWarpStoreClass } from "discourse/services/warp-store";

// `linksMode: true` skips the LegacyNetworkHandler so our handler is the
// sole network layer (routes through Discourse's `ajax()` helper).
class WarpStoreImpl extends useLegacyStore({
  cache: JSONAPICache,
  schemas,
  handlers: [discourseRestHandler],
  linksMode: true,
}) {}

registerWarpStoreClass(WarpStoreImpl);

export default WarpStoreImpl;
