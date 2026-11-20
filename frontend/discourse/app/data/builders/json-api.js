import { filterEmpty } from "@warp-drive/utilities";
import { query as warpQuery } from "@warp-drive/utilities/json-api";

// Exposed here because plugins and themes can't import npm modules directly.
export { filterEmpty };

// JsonApiKit takes list parameters in bracket form (`include[]=…`).
export function query(type, params, options = {}) {
  return warpQuery(type, params, {
    urlParamsSettings: { arrayFormat: "bracket" },
    ...options,
  });
}
