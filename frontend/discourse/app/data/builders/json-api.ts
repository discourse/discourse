import type { QueryParamsSource } from "@warp-drive/core/types/params";
import type {
  ConstrainedRequestOptions,
  QueryRequestOptions,
} from "@warp-drive/core/types/request";
import { filterEmpty } from "@warp-drive/utilities";
import { query as warpQuery } from "@warp-drive/utilities/json-api";

// Exposed here because plugins and themes can't import npm modules directly.
export { filterEmpty };

// JsonApiKit takes list parameters in bracket form (`include[]=…`).
export function query(
  type: string,
  params?: QueryParamsSource,
  options: ConstrainedRequestOptions = {}
): QueryRequestOptions {
  return warpQuery(type, params, {
    urlParamsSettings: { arrayFormat: "bracket" },
    ...options,
  });
}
