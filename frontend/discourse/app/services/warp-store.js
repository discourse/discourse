import { JSONAPICache } from "@warp-drive/json-api";
import { useLegacyStore } from "@warp-drive/legacy";
import discourseRestHandler from "discourse/data/handlers/discourse-rest";
import { schemas } from "discourse/data/schemas";

// `linksMode: true` skips the LegacyNetworkHandler so our handler is the
// sole network layer (routes through Discourse's `ajax()` helper).
export default class WarpStore extends useLegacyStore({
  cache: JSONAPICache,
  schemas,
  handlers: [discourseRestHandler],
  linksMode: true,
}) {}
